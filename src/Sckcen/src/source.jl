
struct SourceTerm{T}
    duration::Interval{<:DateTime}
    rate::typeof(1.0Bq/s)
    SourceTerm(elem::Symbol, args...) = new{elem}(args...)
end

SourceTerm(elem::Symbol, start::DateTime, stop::DateTime, rate) = SourceTerm(elem, start..stop, rate)
function Activity(source::SourceTerm{T}) where T
    Activity(T, total_activity(source))
end

total_activity(source::SourceTerm) = uconvert(Bq, (source.duration.last - source.duration.first) * source.rate)