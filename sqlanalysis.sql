# overall production performance

select*
from production_runs pr 
;

# overall production metrics by product

select 
	product_id,
	count(*) as total_runs,
	sum(target_quantity) as total_target,
	sum(actual_quantity) as total_produced,
	round(avg(actual_quantity/target_quantity * 100), 2) as avg_yield_percentage,
	round(sum(actual_quantity)/SUM(target_quantity) * 100, 2) as total_yield_percentage
from production_runs pr 
group by product_id 
order by total_runs desc 
;

# production trend over time

select 
	date_format(start_time, '%Y-%m') as month,
	count(*) as total_runs,
	sum(target_quantity) as target_quantity,
	sum(actual_quantity) as actual_quantity,
	round(avg(actual_quantity/target_quantity * 100), 2) as yield_percentage
from production_runs pr 
group by date_format(start_time, '%Y-%m')
order by month
;

# quality analysis

select *
from production_runs pr 
;

# quality metrics by product

select 
	pr.product_id,
	count(distinct pr.run_id) as total_runs,
	count(qc.check_id) as total_checks,
	sum(case when qc.pass_fail = 1 then 1 else 0 end) as passed_checks,
	round(sum(case when qc.pass_fail = 1 then 1 else 0 end) * 100.0 / count(qc.check_id), 2) as pass_rate,
	count(distinct case when d.defect_id is not null then qc.check_id end) as checks_with_defects
from production_runs pr 
left join quality_checks qc on pr.run_id = qc.run_id 
left join defects d on qc.check_id = d.check_id 
group by pr.product_id 
order by pass_rate desc
;

# defect analysis

select 
	d.defect_type,
	d.severity,
	count(*) as defect_count,
	round(avg(d.rework_cost), 2) as avg_rework_cost,
	sum(d.rework_cost) as total_rework_cost,
	round(count(*) * 100.0 / (select count(*) from defects), 2) as percentage_of_total
from defects d
group by d.defect_type, d.severity
order by defect_count desc
;

# machine performance

select *
from production_runs pr 
;

# machine reliability analysis

select 
	pr.machine_id,
	count(distinct pr.run_id) as total_runs,
	round(avg(pr.actual_quantity/pr.target_quantity * 100), 2) as avg_yield_percentage,
	count(distinct mm.maintenance_id) as maintenance_count,
	round(avg(mm.cost), 2) as avg_maintenance_cost,
	count(distinct case when mm.maintenance_type = 'emergency' then mm.maintenance_id end) as emergency_repairs
from production_runs pr 
left join machine_maintenance mm on pr.machine_id = mm.machine_id 
group by pr.machine_id 
order by total_runs desc;

# machine maintenance patterns

select 
	machine_id,
	maintenance_type,
	count(*)  as maintenance_count,
	round(avg(case when status = 'completed' then cost else null end), 2) as avg_cost,
	round(avg(case
		when completed_date is not null
		then timestampdiff(hour, scheduled_date, completed_date)
		else null
	end), 1) as avg_completion_hours
from machine_maintenance mm 
group by machine_id, maintenance_type 
order by machine_id, maintenance_count desc
;

# time based analysis

select *
from production_runs pr 
;

# daily production quality trend

select 
	date(pr.start_time) as production_date,
	count(distinct pr.run_id) as total_runs,
	round(avg(case when qc.pass_fail = 1 then 1 else 0 end) * 100, 2) as first_pass_yield,
	count(distinct case when d.severity = 'critical' then d.defect_id end) as critical_defects
from production_runs pr 
left join quality_checks qc on pr.run_id = qc.run_id 
left join defects d on qc.check_id = d.check_id 
group by date(pr.start_time)
order by production_date
;

# hourly production analysis

select 
	hour(start_time) as hour_of_day,
	count(*) as total_runs,
	round(avg(actual_quantity/target_quantity * 100), 2) as avg_yield_percentage,
	count(distinct operator_id) as distinct_operators
from production_runs pr 
group by hour(start_time)
order by hour_of_day
;

# advanced performance metrics

select *
from production_runs pr 
;

# overall equipment effectiveness approximation
-- (OEE) | availability * performance * quality

with productionmetrics as (
	select 
		pr.machine_id,
		count(distinct pr.run_id) as total_runs,
		# availabilitty
		(1 - (count(distinct case when mm.status = 'completed' then mm.maintenance_id end) / count(distinct pr.run_id))) as availability,
		# performance
		avg(pr.actual_quantity/pr.target_quantity) as performance,
		# quality
		avg(case when qc.pass_fail = 1 then 1 else 0 end) as quality
	from production_runs pr
	left join machine_maintenance mm on pr.machine_id = mm.machine_id
	left join quality_checks qc on pr.run_id = qc.run_id
	group by pr.machine_id
)
select 
	machine_id,
	total_runs,
	round(availability * 100, 2) as availability_rate,
	round(performance * 100, 2) as performance_rate,
	round(quality * 100, 2) as quality_rate,
	round(availability * performance * quality * 100, 2) as OEE
from productionmetrics
order by OEE desc 
;

# early warning system query
-- will identify patterns that could predict quality issues

select 
	pr.machine_id,
	count(*) as total_runs,
	avg(case when qc.pass_fail = 0 then 1 else 0 end) as defect_rate,
	avg(pr.actual_quantity/pr.target_quantity) as efficiency,
	count(distinct case when mm.maintenance_type = 'emergency' then mm.maintenance_id end) as emergency_repairs
from production_runs pr 
left join quality_checks qc on pr.run_id = qc.run_id 
left join machine_maintenance mm on pr.machine_id = mm.machine_id 
group by pr.machine_id 
having avg(case when qc.pass_fail = 0 then 1 else 0 end) > 0.05
	or count(distinct case when mm.maintenance_type = 'emergency' then mm.maintenance_id END) > 2
;

# production efficiency by time of day

select 
	hour(pr.start_time) as hour_of_day,
	count(*) as total_runs,
	round(avg(pr.actual_quantity/pr.target_quantity) * 100, 2) as efficiency,
	round(avg(case when qc.pass_fail = 1 then 1 else 0 end) * 100, 2) as quality_rate,
	count(distinct pr.operator_id) as unique_operators
from production_runs pr
left join quality_checks qc on pr.run_id = qc.run_id 
group by hour(pr.start_time)
order by efficiency desc 
;

# cost impact analysis

select 
	pr.product_id,
	count(distinct d.defect_id) as total_defects,
	round(sum(d.rework_cost), 2) as total_rework_cost,
	round(avg(d.rework_cost), 2) as avg_rework_cost,
	sum(case when d.severity = 'critical' then 1 else 0 end) as critical_defects
from production_runs pr
join quality_checks qc on pr.run_id = qc.run_id 
join defects d on qc.check_id = d.check_id 
group by pr.product_id 
order by total_rework_cost desc 
;

# specialized product performance analysis

select 
	pm.*,
	qm.total_checks,
	qm.passed_checks,
	qm.pass_rate,
	qm.total_defects
from production_metrics pm
join quality_metrics qm on pm.product_id = qm.product_id 
order by pm.yield_percentage desc
;

# machine performance with daily trends

select 
	mm.machine_id,
	mm.efficiency as overall_efficiency,
	mm.emergency_repairs,
	count(distinct dpm.production_date) as days_operated,
	round(avg(dpm.daily_yield), 2) as avg_daily_yield,
	sum(dpm.failed_checks) as total_failed_checks
from machine_metrics mm
join daily_production_metrics dpm
	on dpm.emergency_repairs > 0
	and mm.emergency_repairs > 0
group by mm.machine_id 
having total_failed_checks > 0
order by avg_daily_yield desc 
;

# quality trend analysis

select 
	dpm.production_date,
	dpm.total_runs,
	dpm.daily_yield,
	dpm.failed_checks,
	dpm.emergency_repairs,
	case 
		when dpm.daily_yield < 95 then 'low yield'
		when dpm.failed_checks > 5 then 'high defects'
		when dpm.emergency_repairs > 0 then 'maintenance issues'
		else 'good performance'
	end as daily_status
from daily_production_metrics dpm
where dpm.production_date >= date_sub(curdate(), interval 30 day)
order by dpm.production_date
;

# efficiency vs. quality correlation
select 
	mm.machine_id,
	mm.efficiency as machine_efficiency,
	qm.pass_rate as quality_rate,
	mm.total_runs,
	mm.emergency_repairs,
	case 
		when mm.efficiency >= 95 and qm.pass_rate >= 95 then 'high performer'
		when mm.efficiency >= 95 and qm.pass_rate < 95 then 'quality issues'
		when mm.efficiency < 95 and qm.pass_rate >= 95 then 'efficiency issues'
		else 'needs attention'
	end as performance_category
from machine_metrics mm
cross join quality_metrics qm
order by mm.efficiency desc 
;