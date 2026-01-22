select *
from [dbo].[ravenstack_subscriptions]

Select *
from [dbo].[ravenstack_support_tickets]

select * 
from [dbo].[ravenstack_feature_usage]


select * 
from [dbo].[ravenstack_churn_events]

select * 
From [dbo].[ravenstack_accounts]


alter table [dbo].[ravenstack_subscriptions]
alter column [start_date] date

alter table [dbo].[ravenstack_subscriptions]
alter column [end_date] date

alter table [dbo].[ravenstack_subscriptions]
alter column [seats] int

alter table [dbo].[ravenstack_subscriptions]
alter column [mrr_amount] int

alter table [dbo].[ravenstack_subscriptions]
alter column [arr_amount] int

alter table [dbo].[ravenstack_subscriptions]
alter column [is_trial] bit

alter table [dbo].[ravenstack_subscriptions]
alter column [upgrade_flag] bit

alter table [dbo].[ravenstack_subscriptions]
alter column [downgrade_flag] bit

alter table [dbo].[ravenstack_subscriptions]
alter column [churn_flag] bit

alter table [dbo].[ravenstack_subscriptions]
alter column [auto_renew_flag] bit


Select
Count(*) as total_rows,
sum (case when end_date is null then 1 else 0 END) as Nulls_end_date
from [dbo].[ravenstack_subscriptions]

Select
Count(*) as total_rows,
sum (case when [satisfaction_score] is null then 1 else 0 END) as Nulls_satisfactionscore
from [dbo].[ravenstack_support_tickets]


Select
Count(*) as total_rows,
sum (case when [feedback_text] is null then 1 else 0 END) as Nulls_feedback
from [dbo].[ravenstack_churn_events]

Select churn_event_id,
Count(*) as DUP
FROM [dbo].[ravenstack_churn_events]
GROUP BY churn_event_id
HAVING COUNT (*) > 1;

Select [account_id],
Count(*) as DUP
FROM [dbo].[ravenstack_accounts]
GROUP BY [account_id]
HAVING COUNT (*) > 1;

Select usage_id,
Count(*) as DUP
FROM [dbo].[ravenstack_feature_usage]
GROUP BY usage_id
HAVING COUNT (*) > 1;

/* integraty tests */

Select [subscription_id],
Count(*) as DUP
FROM [dbo].[ravenstack_subscriptions]
GROUP BY [subscription_id]
HAVING COUNT (*) > 1;


Select [ticket_id],
Count(*) as DUP
FROM ravenstack_support_tickets
GROUP BY [ticket_id]
HAVING COUNT (*) > 1;

Select *
fROM [dbo].[ravenstack_subscriptions]
WHERE mrr_amount < 0

Select *
fROM [dbo].[ravenstack_subscriptions]
WHERE arr_amount < 0

Select *
fROM [dbo].[ravenstack_support_tickets]
WHERE [first_response_time_minutes] < 0

Select *
fROM [dbo].[ravenstack_support_tickets]
WHERE [resolution_time_hours] < 0

Select *
fROM [dbo].[ravenstack_feature_usage]
WHERE [usage_count] < 0


/* what type of subscriptions are the most requested? */


Select plan_tier,
count (*) as 'number of subscribers'
from [dbo].[ravenstack_subscriptions]
GROUP BY plan_tier
order by 'number of subscribers' desc;


/* What coutries are more profitable and bring more subscribers?*/


Select distinct a.Country,
s.plan_tier,
sum (s.mrr_amount) as 'total mrr.amount',
sum (s.arr_amount) as 'total arr.amount',
count (s.subscription_id) as subcription_count
from ravenstack_accounts as a
join [dbo].[ravenstack_subscriptions] as s
on a.account_id = s.account_id
Group by a.country, s.plan_tier
order by a.Country desc;


/* what type of subscriptions is more profitable? */


Select plan_tier,
sum (mrr_amount) as 'total mrr.amount',
sum (arr_amount) as 'total arr.amount'
from [dbo].[ravenstack_subscriptions]
GROUP BY plan_tier
order by 'total arr.amount' desc;



/* what subscriptions plan are more volatile?  */


Select distinct s.plan_tier,
c.reason_code,
count (c.churn_event_id) as churn_count
from [dbo].[ravenstack_churn_events] as c
join [dbo].[ravenstack_subscriptions] as s
on c.account_id = s.account_id
Group by s.plan_tier, c.reason_code
order by s.plan_tier desc;



/* active subscribers per feature*/

select 
    f.feature_name,
    count(distinct f.subscription_id) as active_subscriptions
from ravenstack_feature_usage as f
group by 
    f.feature_name
order by 
    active_subscriptions desc;


/* “power features” vs “nice-to-have”*/

select 
    f.feature_name,
    count(distinct f.subscription_id) as active_subscriptions,
    sum(f.usage_count) as total_usage_count,
    sum(f.usage_duration_secs) as total_usage_duration_secs
from ravenstack_feature_usage as f
group by 
    f.feature_name
order by 
    total_usage_count desc, 
    total_usage_duration_secs desc;


/* engagement vs churn (last 30 days) */

with recent_usage as (
    select
        f.subscription_id,
        sum(f.usage_count) as usage_count_30d,
        sum(f.usage_duration_secs) as usage_duration_30d
    from ravenstack_feature_usage as f
    where f.usage_date >= dateadd(day, -30, convert(date, getdate()))
    group by
        f.subscription_id
),
usage_with_churn as (
    select
        s.subscription_id,
        coalesce(r.usage_count_30d, 0) as usage_count_30d,
        coalesce(r.usage_duration_30d, 0) as usage_duration_30d,
        s.churn_flag
    from ravenstack_subscriptions as s
    left join recent_usage as r
        on s.subscription_id = r.subscription_id
)
select
    churn_flag,
    count(*) as subscriptions,
    avg(usage_count_30d * 1.0) as avg_usage_count_30d,
    avg(usage_duration_30d * 1.0) as avg_usage_duration_30d
from usage_with_churn
group by
    churn_flag;


/* beta feature impact (churn and upgrades) */

with subs_beta_flag as (
    select
        f.subscription_id,
        max(case when f.is_beta_feature = 1 then 1 else 0 end) as used_beta
    from ravenstack_feature_usage as f
    group by
        f.subscription_id
)
select
    sb.used_beta,
    count(*) as subscriptions,
    sum(case when s.churn_flag = 1 then 1 else 0 end) as churned_subs,
    sum(case when s.upgrade_flag = 1 then 1 else 0 end) as upgraded_subs,
    sum(case when s.churn_flag = 1 then 1 else 0 end) * 100.0 / count(*) as churn_rate_pct,
    sum(case when s.upgrade_flag = 1 then 1 else 0 end) * 100.0 / count(*) as upgrade_rate_pct
from subs_beta_flag as sb
join ravenstack_subscriptions as s
    on sb.subscription_id = s.subscription_id
group by
    sb.used_beta;

/* error-heavy features vs churn (by subscription) */

with subs_error_stats as (
    select
        f.subscription_id,
        sum(f.usage_count) as total_usage_count,
        sum(f.error_count) as total_error_count,
        case 
            when sum(f.usage_count) = 0 then 0.0
            else sum(f.error_count) * 1.0 / sum(f.usage_count)
        end as error_rate
    from ravenstack_feature_usage as f
    group by
        f.subscription_id
)
select
    case 
        when se.error_rate >= 0.1 then 'high_error_rate'
        when se.error_rate > 0 then 'low_error_rate'
        else 'no_errors'
    end as error_bucket,
    count(*) as subscriptions,
    sum(case when s.churn_flag = 1 then 1 else 0 end) as churned_subs,
    sum(case when s.churn_flag = 1 then 1 else 0 end) * 100.0 / count(*) as churn_rate_pct
from subs_error_stats as se
join ravenstack_subscriptions as s
    on se.subscription_id = s.subscription_id
group by
    case 
        when se.error_rate >= 0.1 then 'high_error_rate'
        when se.error_rate > 0 then 'low_error_rate'
        else 'no_errors'
    end;


/* what features are the most used?*/


Select s.plan_tier,
f.feature_name,
count ( f.usage_count) as total_usage
from [dbo].[ravenstack_subscriptions] as s
join [dbo].[ravenstack_feature_usage] as f
on s.subscription_id = f.subscription_id
Group by s.plan_tier, f.feature_name
order by plan_tier desc;


/* what features has a better maintenance / Profitability ratio ? */


Select f.feature_name,
sum (s.arr_amount) as sum_arr,
sum (s.mrr_amount) as sum_mrr,
count (t.ticket_id) as total_tickets
from [dbo].[ravenstack_subscriptions] as s
join [dbo].[ravenstack_feature_usage] as f
on s.subscription_id = f.subscription_id
join [dbo].[ravenstack_support_tickets] as t
on t.account_id = s.account_id
Group by s.plan_tier, f.feature_name
order by plan_tier desc;


/* how is our revenue evolving overtime? */

Select distinct a.Country,
s.start_date,
s.end_date,
sum (s.mrr_amount) as 'total mrr.amount',
sum (s.arr_amount) as 'total arr.amount',
count (s.subscription_id) as subcription_count
from ravenstack_accounts as a
join [dbo].[ravenstack_subscriptions] as s
on a.account_id = s.account_id
Group by a.country, s.start_date, s.end_date
order by s.end_date desc;


/* revenue by segment */

select
    a.industry,
    a.country,
    s.plan_tier,
    s.billing_frequency,
    sum(s.mrr_amount) as total_mrr,
    sum(s.arr_amount) as total_arr
from ravenstack_accounts as a
join ravenstack_subscriptions as s
    on a.account_id = s.account_id
group by
    a.industry,
    a.country,
    s.plan_tier,
    s.billing_frequency
order by
    a.industry,
    a.country,
    s.plan_tier,
    s.billing_frequency;


/* revenue concentration: top 10 accounts by arr*/

select top 10
    a.account_id,
    a.account_name,
    a.industry,
    a.country,
    sum(s.arr_amount) as total_arr
from ravenstack_accounts as a
join ravenstack_subscriptions as s
    on a.account_id = s.account_id
group by
    a.account_id,
    a.account_name,
    a.industry,
    a.country
order by
    total_arr desc;

/* expansion vs contraction (upgrade / downgrade mrr and net mrr)*/

select
    sum(case when s.upgrade_flag = 1 then s.mrr_amount else 0 end) as expansion_mrr,
    sum(case when s.downgrade_flag = 1 then s.mrr_amount else 0 end) as downgrade_mrr,
    sum(case when s.upgrade_flag = 1 then s.mrr_amount else 0 end)
      - sum(case when s.downgrade_flag = 1 then s.mrr_amount else 0 end) as net_mrr_growth
from ravenstack_subscriptions as s;



/* overall expansion / contraction*/

select
    sum(case when s.upgrade_flag = 1 then s.mrr_amount else 0 end) as expansion_mrr,
    sum(case when s.downgrade_flag = 1 then s.mrr_amount else 0 end) as downgrade_mrr,
    sum(case when s.upgrade_flag = 1 then s.mrr_amount else 0 end)
      - sum(case when s.downgrade_flag = 1 then s.mrr_amount else 0 end) as net_mrr_growth
from ravenstack_subscriptions as s;


/* by month (using start_date as the event month)*/

select
    datefromparts(year(s.start_date), month(s.start_date), 1) as change_month,
    sum(case when s.upgrade_flag = 1 then s.mrr_amount else 0 end) as expansion_mrr,
    sum(case when s.downgrade_flag = 1 then s.mrr_amount else 0 end) as downgrade_mrr,
    sum(case when s.upgrade_flag = 1 then s.mrr_amount else 0 end)
      - sum(case when s.downgrade_flag = 1 then s.mrr_amount else 0 end) as net_mrr_growth
from ravenstack_subscriptions as s
group by
    datefromparts(year(s.start_date), month(s.start_date), 1)
order by
    change_month;


/*trial performance: trial → paid conversion rate */

with trial_subs as (
    select
        s.account_id,
        min(s.start_date) as first_trial_start
    from ravenstack_subscriptions as s
    where s.is_trial = 1
    group by
        s.account_id
),
paid_after_trial as (
    select distinct
        t.account_id
    from trial_subs as t
    join ravenstack_subscriptions as s
        on t.account_id = s.account_id
       and s.is_trial = 0
       and s.start_date >= t.first_trial_start
)
select
    (select count(*) from trial_subs) as trial_accounts,
    (select count(*) from paid_after_trial) as converted_accounts,
    (select count(*) * 100.0 from paid_after_trial) 
        / nullif((select count(*) from trial_subs), 0) as trial_conversion_rate_pct;




/* what features are causing the subscribers to stay subscribed for longer? */


Select distinct f.feature_name,
a.Country,
a.plan_tier,
datediff(day,s.start_date,s.end_date) as days_duration,
sum (s.mrr_amount) as 'total mrr.amount',
sum (s.arr_amount) as 'total arr.amount',
count (s.subscription_id) as subcription_count
from ravenstack_accounts as a
join [dbo].[ravenstack_subscriptions] as s
on a.account_id = s.account_id
join [dbo].[ravenstack_feature_usage] as f
on f.subscription_id = s.subscription_id
Group by a.country, f.feature_name, a.plan_tier, datediff(day,s.start_date,s.end_date)
order by days_duration desc;


/* do we have a lot of support tickets? */

600

select count (*) / 600 as percentage_of_cancelations
from ravenstack_subscriptions


/* Churn & Retention*/

/* Lost MRR/ARR from churned subs per month*/


select 
year(s.end_date) as churn_year,
month(s.end_date) as churn_month,
sum (s.mrr_amount) as 'total mrr.amount lost',
sum (s.arr_amount) as 'total arr.amount lost'
from [dbo].[ravenstack_accounts] as a 
join [dbo].[ravenstack_subscriptions] as s
on s.account_id = a.account_id
where a.churn_flag = 1
and s.end_date is not null
group by
year(s.end_date),
month(s.end_date)
order by churn_year,
churn_month;



/* Percentage of churns*/

with churn_events as ( select 
count (distinct a.account_id) as total_churn
from [dbo].[ravenstack_accounts] as a
left join ravenstack_churn_events as e
on a.account_id = e.account_id
left join ravenstack_subscriptions as s
on a.account_id = s.account_id
where a.churn_flag = 1 or s.churn_flag = 1 or e.account_id is not null),
totals as (select count (*) as total_accounts from ravenstack_accounts)
select total_churn,
total_accounts,
total_churn * 100.0 / total_accounts as logo_churn_rate_pct
from churn_events, totals


/* Percentage of churns by year, industry*/


with churned_accounts as (
    select distinct
        a.account_id,
        a.industry,
        datepart(year, e.churn_date) as churn_year
    from ravenstack_accounts as a
    left join ravenstack_churn_events as e
        on a.account_id = e.account_id
    where a.churn_flag = 1 
       or e.account_id is not null
),
account_base as (
    select
        a.account_id,
        a.industry
    from ravenstack_accounts as a
)
select
    ca.churn_year,
    ca.industry,
    count(distinct ca.account_id) as churned_accounts,
    count(distinct ab.account_id) as total_accounts,
    count(distinct ca.account_id) * 100.0 
        / count(distinct ab.account_id) as logo_churn_rate_pct
from churned_accounts as ca
join account_base as ab
    on ca.industry = ab.industry
group by
    ca.churn_year,
    ca.industry
order by
    ca.churn_year,
    ca.industry;


/* Percentage of churns by year, plan_tier */

with churned_accounts as (
    select distinct
        a.account_id,
        a.plan_tier,
        datepart(year, e.churn_date) as churn_year
    from ravenstack_accounts as a
    left join ravenstack_churn_events as e
        on a.account_id = e.account_id
    where a.churn_flag = 1 
       or e.account_id is not null
),
account_base as (
    select
        a.account_id,
        a.plan_tier
    from ravenstack_accounts as a
)
select
    ca.churn_year,
    ca.plan_tier,
    count(distinct ca.account_id) as churned_accounts,
    count(distinct ab.account_id) as total_accounts,
    count(distinct ca.account_id) * 100.0 
        / count(distinct ab.account_id) as logo_churn_rate_pct
from churned_accounts as ca
join account_base as ab
    on ca.plan_tier = ab.plan_tier
group by
    ca.churn_year,
    ca.plan_tier
order by
    ca.churn_year,
    ca.plan_tier;


    
/* Percentage of churns by year, plan_tier and industry */

with churned_accounts as (
    select distinct
        a.account_id,
        a.industry,
        a.plan_tier,
        datepart(year, e.churn_date) as churn_year
    from ravenstack_accounts as a
    left join ravenstack_churn_events as e
        on a.account_id = e.account_id
    left join ravenstack_subscriptions as s
        on a.account_id = s.account_id
    where a.churn_flag = 1
       or s.churn_flag = 1
       or e.account_id is not null
),
account_base as (
    select
        a.account_id,
        a.industry,
        a.plan_tier
    from ravenstack_accounts as a
)
select
    case 
        when ca.churn_year is null then 'account still active'
        else cast(ca.churn_year as varchar(10))
    end as churn_year_label,
    ca.industry,
    ca.plan_tier,
    count(distinct ca.account_id) as churned_accounts,
    count(distinct ab.account_id) as total_accounts,
    count(distinct ca.account_id) * 100.0 
        / count(distinct ab.account_id) as logo_churn_rate_pct
from churned_accounts as ca
join account_base as ab
    on ca.industry = ab.industry
   and ca.plan_tier = ab.plan_tier
group by
    case 
        when ca.churn_year is null then 'account still active'
        else cast(ca.churn_year as varchar(10))
    end,
    ca.industry,
    ca.plan_tier
order by
    churn_year_label,
    ca.industry,
    ca.plan_tier;


/* Churn events by reason_code, refund_amount_usd, and industry/country.*/


Select e.reason_code,
e.refund_amount_usd,
a.industry,
a.country,
s.plan_tier,
s.seats
from ravenstack_accounts as a
    left join ravenstack_churn_events as e
        on a.account_id = e.account_id
    left join ravenstack_subscriptions as s
        on a.account_id = s.account_id
    where a.churn_flag = 1
       or s.churn_flag = 1
       or e.account_id is not null
group by 
e.reason_code,a.industry,e.refund_amount_usd,a.country,s.plan_tier,s.seats
order by e.refund_amount_usd desc ;


/* is churn more likely after upgrade/downgrade?*/

with churn_labels as (
    select distinct
        e.account_id,
        datepart(year, e.churn_date) as churn_year,
        datepart(quarter, e.churn_date) as churn_quarter,
        case
            when e.preceding_upgrade_flag = 1 then 'after_upgrade'
            when e.preceding_downgrade_flag = 1 then 'after_downgrade'
            else 'no_prior_change'
        end as prior_change_type
    from ravenstack_churn_events as e
),
accounts_base as (
    select a.account_id
    from ravenstack_accounts as a
)
select
    cl.churn_year,
    cl.churn_quarter,
    cl.prior_change_type,
    count(distinct cl.account_id) as churned_accounts,
    count(distinct ab.account_id) as total_accounts,
    count(distinct cl.account_id) * 100.0 
        / count(distinct ab.account_id) as churn_rate_pct
from churn_labels as cl
cross join accounts_base as ab
group by
    cl.churn_year,
    cl.churn_quarter,
    cl.prior_change_type
order by
    cl.churn_year,
    cl.churn_quarter,
    cl.prior_change_type;

