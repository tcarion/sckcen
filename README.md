# Selenium 75 release at SCK-CEN - An approach with ensembles.

This code base is using the [Julia Language](https://julialang.org/) and
[DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/)
to make a reproducible scientific project named
> sckcen

It is authored by Tristan Carion.

To (locally) reproduce this project, do the following:

0. Download this code base. Notice that raw data are typically not included in the
   git-history and may need to be downloaded independently.
1. Open a Julia console and do:
   ```
   julia> using Pkg
   julia> Pkg.add("DrWatson") # install globally, for using `quickactivate`
   julia> Pkg.activate("path/to/this/project")
   julia> ]
   julia> dev 
   julia> Pkg.instantiate()
   ```

This will install all necessary packages for you to be able to run the scripts and
everything should work out of the box, including correctly finding local paths.

You may notice that most scripts start with the commands:
```julia
using DrWatson
@quickactivate
```
which auto-activate the project and enable local path handling from DrWatson.

## Introduction
This project is based on the preliminary work done in [Frankemölle et al](https://linkinghub.elsevier.com/retrieve/pii/S0265931X2200203X). This work compared the monitored dose rates induced by an accidental release of Selenium 75 in the SCK-CEN facilities with the dose rates calculated with a Gaussian dispersion model and the FLEXPART model. 

This project aims at using meteorological ensembles and Monte Carlo methods with those dispersion models to perform ensemble verification with the monitored data.

## Files structure
The files of this repo are mostly organized following the [DrWatson](https://juliadynamics.github.io/DrWatson.jl/stable/) structure. Yet, we'll give more detail here about the content of the folders.

The code hosted on this repo is mostly contained in the `src` and the `scripts` folders. The other folders are empty on this repo. Their content can be found on the NextCloud storage associated with this project.

The folders will be briefly described here, but additional information can be found on the folders dedicated README's.

- `src` defines the functions, the data structures and the constants used in the `scripts` and the `notebooks`. It also contains the Sckcen.jl package used to calculate the gamma dose rates, among other things.
- `scripts` use the code in `src` to prepare, run and postprocess the simulations.
- `data` contains mostly the input weather data and the simulation results.
- `plots` is where the some of the plots generated in `scripts` are saved.
- `notebooks` is where the results are postprocessed and somewhat interpreted using the code from `src`.

## Caveat
- This project will work only work with Julia 1.7, due to an issue with Flexpart.jl (see [this issue](https://github.com/tcarion/Flexpart.jl/issues/9))