const RELLAT = 51.21507
const RELLON = 5.09597

const RELHEIGHT = 60.

const RELSTART = "2019-05-15T15:10:00"

const RELSTEPS_MINUTE = fill(10, 6)

# Bq / s
const RELEASE_RATE = [9.1, 8.6, 4.1, 1.6, 1.0, 0.9] .* 1e6

const RELEASE_TIMES = accumulate(+, Minute.(RELSTEPS_MINUTE), init = DateTime(RELSTART))