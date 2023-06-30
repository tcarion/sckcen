using DataFrames
using DataFramesMeta
using Markdown

function all_scores(oper, ens, obs; with = "mean")
    by_fcstart_ens = combine(groupby(ens, [:time, :forecast_start, :receptorName]), 
        :H10 => mean => :sim_mean, 
        :H10 => median => :sim_median, 
        :H10 => std => :sim_std, 
        :H10 => var => :sim_var
    )

    ensemble_stats = combine(groupby(ens, [:time, :receptorName]), 
        :H10 => mean, 
        :H10 => median, 
        :H10 => std, 
        :H10 => var
    )

    joined_oper = innerjoin(oper, obs, on = [:time => :stop, :receptorName => :longName])
    joined_byfcs_ens = innerjoin(by_fcstart_ens, obs, on = [:time => :stop, :receptorName => :longName])
    joined_ens_all = innerjoin(ensemble_stats, obs, on = [:time => :stop, :receptorName => :longName])

    # oper_bias, by_fcs_bias, ens_bias = _biases(joined_oper, joined_byfcs_ens, joined_ens_all; with)
    # oper_rmse, by_fcs_rmse, ens_rmse = _rmses(joined_oper, joined_byfcs_ens, joined_ens_all; with)

    entrynames = ["deterministic, 15th of May at 14h", ["ensemble, "*Dates.format(r, "ddth of \\Ma\\y at HHh") for r in unique(sort(joined_byfcs_ens, :forecast_start).forecast_start)]..., "ensemble, all"]

    biases = _process_score(joined_oper, joined_byfcs_ens, joined_ens_all, _bias; with)
    rmses = _process_score(joined_oper, joined_byfcs_ens, joined_ens_all, _rmse; with)
    frac_biases = _process_score(joined_oper, joined_byfcs_ens, joined_ens_all, _fractional_bias; with)
    
    _tovec(x, prop) = [getproperty(x[1], prop)[1], getproperty(x[2], prop)..., getproperty(x[end], prop)[1]]
    return DataFrame(
        entryname = entrynames,
        bias = _tovec(biases, :bias),
        rmse = _tovec(rmses, :rmse),
        fractional_bias = _tovec(frac_biases, :fractional_bias)
    )
end

_bias(x, y) = mean(x .- y)

_rmse(x, y) = sqrt(mean((x .- y).^2))

_fractional_bias(x, y) = 2 * _bias(x, y) / (mean(x) + mean(y))

function _process_score(joined_oper, joined_byfcs_ens, joined_ens_all, score_fun::Function; with = "mean")
    colvalue_byfcs = with == "mean" ? :sim_mean : :sim_median
    colvalue_all = with == "mean" ? :H10_mean : :H10_median
    score_colname = Symbol(String(Symbol(score_fun))[2:end])
    oper_score = combine(joined_oper, [:H10, :value] => score_fun => score_colname)
    by_fcs_score = @chain joined_byfcs_ens begin
        groupby(_, [:forecast_start])
        combine(_, [colvalue_byfcs, :value] => score_fun => score_colname)
    end
    ens_score = combine(joined_ens_all, [colvalue_all, :value] => score_fun => score_colname)
    return oper_score, by_fcs_score, ens_score
end

function ensemble_spread(fc; fc_val = :H10)
    by_members = groupby(fc, [:forecast_start, :receptorName, :time])
    with_mean = transform(by_members, fc_val => mean)
end

function all_spreads(df)

end

function all_means(df)

end

function combine_h10(dose_rates_df)

end