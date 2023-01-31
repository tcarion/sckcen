abstract type AbstractElement end

const AVOGADRO_CONSTANT = 6.02214179e23u"mol^-1"
const NUCLIDE_DATA_DIR = pkgdir(@__MODULE__, "data", "nuclides")

Base.@kwdef struct Element <: AbstractElement
    id::String = "Se-75"
    "Molar Mass"
    M::typeof(1.0g*mol^-1) = 78.971g*mol^-1
    "Half life time"
    tₕ::Unitful.Time = 10.3491e6s
    "Density"
    ρ::typeof(1.0kg/m^3) = 4.79u"g/cm^3"
end

molar_mass(elem::AbstractElement)::Float64 = ustrip(uconvert(g/mol, elem.M))
half_life(elem::AbstractElement)::Float64  = ustrip(upreferred(elem.tₕ))
density(elem::AbstractElement)::Float64  = ustrip(upreferred(elem.ρ))

Base.@kwdef struct Activity
    element::AbstractElement = Element()
    A::typeof(1.0Bq) = 1.49e10Bq
end

# Activity(; element::AbstractElement, A::Number) = Activity(; element, A = A * Bq)

function get_mass(activity::Activity) 
    mass = activity.A * activity.element.M * activity.element.tₕ / (AVOGADRO_CONSTANT * log(2))
    uconvert(g, mass)
end

"""
    attenuation_coefs(Ey, ρ)
Yields attenuation coefficients of air as described in Martin (2013), given the energy of gamma ray `Ey` [keV] and the
density of air `ρ` [g/cm³]. Return `mu` the mass attenuation and `mu_en` the mass energy absorption, both in [1/m].
Martin, J.E. (2013) Physics for Radiation Protection, Weinheim: Wiley. DOI:
    https://doi.org/10.1002/9783527667062
"""
function attenuation_coefs(Ey::AbstractFloat, ρ::AbstractFloat)
    mu = INTERP_MU(Ey) * ρ * 100
    mu_en = INTERP_MUₑₙ(Ey) * ρ * 100
    mu, mu_en
end

attenuation_coefs(Ey::Unitful.Energy, ρ::Unitful.Density) = attenuation_coefs(ustrip(uconvert(u"keV", Ey)), ustrip(uconvert(u"g/cm^3", ρ))) .* u"m^-1"
"""
    maybe_download_lara(nuclide_id::AbstractString)
Download the nuclides data from http://www.lnhb.fr/Laraweb/ if not yet available. `nuclide_id` is the name of the nuclide in the form "Se-75".
In any case, return the path to the file.
"""
function maybe_download_lara(nuclide_id::AbstractString)
    filename = _nuclide_file_name(nuclide_id)
    filepath = _nuclide_file_path(nuclide_id)
    isfile(filepath) && (return filepath)
    return Downloads.download(
        "http://www.lnhb.fr/Laraweb/Results/"*filename,
        filepath
    )
end

function read_lara_file(nuclide_id::AbstractString)
    filepath = maybe_download_lara(nuclide_id)

    lara_data = Dict{Symbol, Any}()
    matrix_file = readdlm(filepath, ';')

    # Function that find the value (second column) by checking if `x` occurs in the first column
    _line_value = x -> strip(matrix_file[findfirst(y -> occursin(x, y), matrix_file[:, 1]), 2])
    lara_data[:nuclide] = _line_value("Nuclide")
    lara_data[:element] = _line_value("Element")
    energy_line_start = findfirst(x -> occursin("----", x), matrix_file[:,1]) + 1
    energy_matrix = matrix_file[energy_line_start:end-1, :]
    colnames = strip.(energy_matrix[1, :])
    energy_df = DataFrame(energy_matrix[2:end, :], colnames)

    lara_data[:Ey] = Float64.(energy_df[:, "Energy (keV)"])
    lara_data[:I] = Float64.(energy_df[:, "Intensity (%)"] / 100)
    return (; lara_data...)
end

_nuclide_file_path(nuclide_id) = joinpath(NUCLIDE_DATA_DIR, _nuclide_file_name(nuclide_id))
_nuclide_file_name(nuclide_id) = nuclide_id*".lara.txt"