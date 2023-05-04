abstract type AbstractElement end

const AVOGADRO_CONSTANT = 6.02214179e23u"mol^-1"
const NUCLIDE_DATA_DIR = pkgdir(@__MODULE__, "data", "nuclides")

const BqQuantity = Union{typeof(1.0Bq), typeof(1.0f0 * Bq)}
const MQuantity = Union{typeof(1.0g*mol^-1), typeof(1.0f0 * g*mol^-1)}

const INTERP_MU = linear_interpolation(ATTENUATION_COEFS_AIR[:, 1], ATTENUATION_COEFS_AIR[:, 3])
const INTERP_MUₑₙ = linear_interpolation(ATTENUATION_COEFS_AIR[:, 1], ATTENUATION_COEFS_AIR[:, 4])

bilinear_interpolation(data) = extrapolate(interpolate((data.μx, data.Eᵧ), data.Bs, Gridded(Linear())), Flat())

const INTERP_KERMA = linear_interpolation(CONVERSION_COEFS[:, 1], CONVERSION_COEFS[:, 2])

const INTERP_MARTIN_B = bilinear_interpolation(MARTIN_BUILDUP_FACTORS)

const INTERP_TRUBEY_B = bilinear_interpolation(TRUBEY_BUILDUP_FACTORS)

struct Element{T} <: AbstractElement
    id::String
    "Molar Mass"
    M::typeof(1.0g*mol^-1)
    "Half life time"
    tₕ::Unitful.Time
    "Density"
    ρ::typeof(1.0kg/m^3)
end

molar_mass(elem::AbstractElement)::Float64 = ustrip(uconvert(g/mol, elem.M))
half_life(elem::AbstractElement)::Float64  = ustrip(upreferred(elem.tₕ))
density(elem::AbstractElement)::Float64  = ustrip(upreferred(elem.ρ))

@valsplit function Element(Val(Se75::Symbol))
    Element{Se75}(
        "Se-75", 
        78.971g*mol^-1, 
        10.3491e6s,
        4.79u"g/cm^3"
    )
end

Element() = Element(:Se75)

struct Activity{T}
    A::typeof(1.0Bq)
    Activity(::Element{T}, A) where T = new{T}(A)
end

function Activity(elem::Symbol, A)
    Activity(Element(elem), A)
end


get_element(::Activity{T}) where T = Element(T)

# Activity(; element::AbstractElement, A::Number) = Activity(; element, A = A * Bq)

function get_mass(activity::Activity{T}) where T
    element =  get_element(activity)
    mass = activity2mass(activity.A, element.M, element.tₕ)
    uconvert(g, mass)
end

activity2mass(A::BqQuantity, M::MQuantity, tₕ::Unitful.Time) = A * M * tₕ / (AVOGADRO_CONSTANT * log(2))
mass2activity(m::Unitful.Mass, M::MQuantity, tₕ::Unitful.Time) = uconvert(Bq, m * AVOGADRO_CONSTANT * log(2) / (M * tₕ))
mass2activity(m, M, tₕ) = m * AVOGADRO_CONSTANT * log(2) / (M * tₕ)

function mass2activity(elem::Symbol, m::Unitful.Quantity)
    element = Element(elem)
    mass2activity(m, element.M, element.tₕ)
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

"""
function Gy_to_H10(Ka, Ey)
    Ka*INTERP_KERMA(Ey/1e3)
end

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

    subset!(energy_df, "Type" => x -> strip.(x) .== "g") # Only considers gamma rays
    lara_data[:Ey] = Float64.(energy_df[:, "Energy (keV)"])
    lara_data[:I] = Float64.(energy_df[:, "Intensity (%)"] / 100)
    return (; lara_data...)
end


"""
    gamma_dose_rate_factors(conc, receptor, nuclide_data, rho)
Calculates the gamma dose rate to air (Healy and Baker, 1968) and the 
ambient dose equivalent rate for a unit release and outputs an array gf_H10
for all grid cells such that:
    
    ambient dose equivalent rate = sum(gf_H10*c)
    
where c is the array of concentrations.
This is currently only valid for regular and small extend grids.

# Acknowledgment
This is largely inspired from the Python ADDER model (https://gitlab.com/jpfr95/adder) written by Jens Peter Frankemölle.
"""
function gamma_dose_rate_factors(conc, receptor, nuclide_data, rho)
    D = zero(conc)
    H10 = zero(conc)
    for (Ey, I) in zip(nuclide_data.Ey*u"keV", nuclide_data.I)
        mu, mu_en = attenuation_coefs(Ey, rho)
        prefac = _prefactor(Ey, mu_en, rho)
        mux = _mux(mu, conc, receptor)
        B = _buildup_factor.(Ey, mux)

        q = 1.0 * _δV(conc) / 3.7e10

        Dr = _δDᵣ.(ustrip(prefac), q, B, mux, ustrip(mu))
        try 
            Dr[Z(At(0.))] .= Dr[Z(At(0.))] ./ 2
        catch

        end
        any(Dr .< 0.) && error("$Ey     $I    $(findfirst(Dr .< 0.))")
        Di = I * Dr
        D = D + Di
        EykeV = ustrip(u"keV", Ey)
        H10 = H10 + Gy_to_H10.(Di, EykeV)
    end
    D, H10
end
gamma_dose_rate_factors(conc, receptor::NamedTuple, args...) = gamma_dose_rate_factors(conc, [receptor.lon, receptor.lat, receptor.alt], args...)

function time_resolved_dosimetry(conc, receptor, nuclide_data, rho)
    factors_D, factors_H10 = gamma_dose_rate_factors(conc[Ti = 1], receptor, nuclide_data, rho)
    Tidim = dims(conc, Ti)
    doses = map(enumerate(Tidim)) do (i, t)
        D = sum(conc[Ti = i] .* factors_D)
        H10 = sum(conc[Ti = i] .* factors_H10)
        [D, H10]
    end
    doses = permutedims(hcat(doses...))
    doses[:, 1] * u"nSv/hr", doses[:, 2] * u"nSv/hr"
end

_nuclide_file_path(nuclide_id) = joinpath(NUCLIDE_DATA_DIR, _nuclide_file_name(nuclide_id))
_nuclide_file_name(nuclide_id) = nuclide_id*".lara.txt"

_prefactor(Ey, mu_en, rho) = 1/100 * 0.0364 * (1293 / (ustrip(u"g/m^3", rho))) * ustrip(u"m^-1", mu_en) * ustrip(u"MeV", Ey)

# 3.7e10 is for conversion from Bq to Curie
_q(conc, δx, δy, δz) = δx * δy * δz * conc / 3.7e10
_q(conc::BqQuantity, δx, δy, δz) = _q(ustrip(u"Bq", conc), δx, δy, δz)
_q(δx, δy, δz) = _q(1., δx, δy, δz)

_distance(source, receptor) = distance(source, receptor) * u"m"

function _distance(conc::AbstractDimArray, receptor)
    is_lonlat = crs(conc) == EPSG(4326)
    map(CartesianIndices(conc)) do I
        i, j, k = Tuple(I)
        source = _getcoords(conc, i, j, k)
        if is_lonlat
            _distance(LLA(lat = source[2], lon = source[1], alt = source[3]), receptor)
        else
            _distance(source, receptor)
        end
    end
end

_mux(mu, source, receptor) = mu * _distance(source, receptor)
# _mux(mu, conc::AbstractDimArray, receptor) = mu * _distance(conc, receptor)

_buildup_factor(Ey, mux) = INTERP_TRUBEY_B(mux, Ey)

_δDᵣ(prefac, q, B, mux, mu) = prefac * q * B * exp(-mux)/(mux/mu)^2 * 1e9 * 3600

function _getcoords(A::AbstractDimArray, i, j, k)
    dims = ddims(A, (X, Y, Z))
    # [dims[1][i], dims[2][j], dims[3][k]]
    #! Quite suprisingly, replacing with the following line improve general performance by a factor of 4!
    #! julia> @btime [$dims[1][2], $dims[2][4], $dims[3][7]]
    #! 560.446 ns (9 allocations: 256 bytes)
    #! julia> @btime map((x, m) -> x[m], $dims, [2, 4, 7])
    #! 248.552 ns (10 allocations: 688 bytes)
    #! julia> @btime map((x, m) -> x[m], $dims, (2, 4, 7))
    #! 2.686 ns (0 allocations: 0 bytes)
    map((x, m) -> x[m], dims, (i, j, k))
end

function _δV(conc)
    raster_crs = crs(conc)
    # 
    if raster_crs == EPSG(4326)
        # In case of lonlat grids, the calculation of the cell volume is not straightforward.
        # For now, we consider the volume to be constant over the grid, which is a valid approximation for small extends.
        δlon, δlat, δz = step.(R.dims(conc, (X, Y, Z)))
        lon1 = R.dims(conc, X)[1]
        lat1 = R.dims(conc, Y)[1]
        # We could have used this commented implementation, which has the benefit of simplicity. This use of the `distance` function
        # is more versatile though.
        # δy = δlat * 111320 
        # δx = δlon * 111320 * cosd(lat1)
        δx = distance((lon=lon1, lat=lat1), (lon=lon1 + δlon, lat=lat1))
        δy = distance((lon=lon1, lat=lat1), (lon=lon1, lat=lat1 + δlat))
    else
        δx, δy, δz = step.(dims(conc, (X, Y, Z)))
    end
    δx .* δy .* δz
end