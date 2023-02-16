using Sckcen
using Sckcen: read_lara_file, attenuation_coefs, Gy_to_H10
using Sckcen: _prefactor, _q, _mux, _buildup_factor, _δDᵣ, _getcoords, _distance, _δV
using Sckcen: gamma_dose_rate_factors
using Sckcen.Unitful
using Sckcen.Rasters
using Dates
using BenchmarkTools

nuclide_data = read_lara_file("Se-75")
receptor = [4.7, 50.2, 1.]
rho = 1.2u"kg/m^3"

Ey = nuclide_data.Ey[1]*u"keV"

mu, mu_en = attenuation_coefs(Ey, rho)

prefac = _prefactor(Ey, mu_en, rho)

xs = range(4.698, 4.702, 101)
ys = range(50.198, 50.202, 101)
zs = range(0., 200., 21)
ts = DateTime(2023, 1, 1, 12):Dates.Minute(10):DateTime(2023, 1, 1, 13)
conc_array = Raster(rand(X(xs), Y(ys), Z(zs), Ti(ts)) * 1e5, crs = EPSG(4326))
conc = conc_array[Ti=1]

δx, δy, δz = step.(dims(conc_array, (X, Y, Z)))
i, j, k = 3, 2, 2
q = _q(conc_array[i, j, k, 1], δx, δy, δz)

source = _getcoords(conc_array, i, j, k)

# 167.071 ns (1 allocation: 16 bytes)
mux = _mux(mu, source, receptor)
B = _buildup_factor(Ey, mux)

_δDᵣ(ustrip(prefac), q, B, mux, ustrip(mu))

mux = _mux(mu, conc, receptor)

dist = _distance(conc, receptor)

dV = _δV(conc)
# 2.509 s (44988896 allocations: 1.25 GiB)
D, H10 = gamma_dose_rate_factors(conc, receptor, nuclide_data, rho)