-----------------------------------------------------------------------------------------
-- T-SQL Logger Install
-----------------------------------------------------------------------------------------

raiserror(N'T-SQL Logger',0,1) with nowait;
raiserror(N'Installation Started...',0,1) with nowait;
set nocount on;


-- Create Schema
-----------------------------------------------------------------------------------------
if not exists (select name from sys.schemas where name = N'logger')
begin
	exec('create schema [logger] authorization [dbo]');
	raiserror(N'Schema Installed',0,1) with nowait;
end;


-- Create Tables
-----------------------------------------------------------------------------------------
if object_id(N'logger.logger_logs', N'U') is null
begin
	create table logger.logger_logs 
	(
		[id]			int primary key identity(1,1) not null,
		[logger_level]		int,
		[text]			nvarchar(4000),
		[scope]			nvarchar(1000),
		[time_stamp]		datetime2,
		[session_id]		smallint,
		[service_name]		nvarchar(1000),
		[user_name]		nvarchar(255),
		[client_identifier]	nvarchar(255),
		[error_line]		int, 
		[error_message]		nvarchar(4000), 
		[error_number]		nvarchar(50), 
		[error_procedure]	nvarchar(100), 
		[error_severity]	int,
		[error_state]		int,
		[params]		nvarchar(max),
		[extra]			nvarchar(max)
	);
end;
go

if object_id(N'logger.logger_prefs', N'U') is null
begin
	create table logger.logger_prefs
	(
		pref_name	nvarchar(255),
		pref_value	nvarchar(255)
	);
end;
go
create clustered index [c_idx_logger_prefs] on [logger].[logger_prefs]([pref_name] asc);
go
raiserror(N'Tables Installed',0,1) with nowait;




-- Create Types
-----------------------------------------------------------------------------------------
if type_id(N'logger.logger_tab_param') is null
begin
	create type logger.logger_tab_param as table (name nvarchar(255), val nvarchar(4000));
end;
go


if type_id(N'logger.logger_tab_tran') is null
begin
	create type logger.logger_tab_tran as table
	(
		[id]			int primary key identity(1,1) not null,
		[logger_level]		int,
		[text]			nvarchar(4000),
		[scope]			nvarchar(1000),
		[time_stamp]		datetime2,
		[session_id]		smallint,
		[service_name]		nvarchar(1000),
		[user_name]		nvarchar(255),
		[client_identifier]	nvarchar(255),
		[error_line]		int, 
		[error_message]		nvarchar(4000), 
		[error_number]		nvarchar(50), 
		[error_procedure]	nvarchar(100), 
		[error_severity]	int,
		[error_state]		int,
		[params]		nvarchar(max),
		[extra]			nvarchar(max)
	);
end;
go
raiserror(N'Types Installed',0,1) with nowait;



-- Populate Config
-----------------------------------------------------------------------------------------
merge into logger.logger_prefs p
using (
	select N'PURGE_AFTER_DAYS' pref_name, N'14' pref_value union
	select N'PURGE_MIN_LEVEL' pref_name, N'INFORMATION' pref_value union
	select N'LEVEL' pref_name, N'INFORMATION' pref_value union
	select N'VERBOSE' pref_name, N'1' pref_value union
	select N'VERSION' pref_name, N'1.0' pref_value
) d
on (p.pref_name = d.pref_name)
when matched then
	update set pref_value = p.pref_value
when not matched then
	insert (pref_name, pref_value)
	values (d.pref_name,d.pref_value);
go
raiserror(N'Logger Configuration Loaded',0,1) with nowait;




-- Create Functions
-----------------------------------------------------------------------------------------
if object_id(N'logger.ok_to_log', N'FN') IS NOT NULL
begin
	drop function [logger].[ok_to_log];
end;
go
create function [logger].[ok_to_log] ( @level int )
returns bit
as
begin 
	declare @logger_level int, @ret bit;
	select @logger_level = case pref_value
		when N'OFF' then 0
		when N'PERMANENT' then 1
		when N'ERROR' then 2
		when N'WARNING' then 4
		when N'INFORMATION' then 8
		when N'DEBUG' then 16 end
	from logger.logger_prefs where pref_name = N'LEVEL';
	
	if (@logger_level >= @level)
		set @ret = cast(1 as bit);
	else 
		set @ret = cast(0 as bit);

	return @ret;
end;
go


if object_id(N'logger.get_pref', N'FN') IS NOT NULL
begin
	drop function [logger].[get_pref];
end;
go
create function [logger].[get_pref] ( @pref_name nvarchar(255) )
returns nvarchar(255)
as
begin 
	declare @ret nvarchar(255);
	
	select @ret = pref_value
	from logger.logger_prefs
	where UPPER(pref_name) = UPPER(@pref_name);

	return @ret;
end;
go
raiserror(N'Logger Functions Created',0,1) with nowait;


-- Create Procedures
-----------------------------------------------------------------------------------------
if object_id(N'logger.log_debug', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_debug] 
end;
go
create procedure [logger].[log_debug] 
(
	@text nvarchar(4000),
	@scope nvarchar(1000) = null,
	@params logger.logger_tab_param readonly,
	@extra nvarchar(max) = null
)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @ok_to_log bit, @verbose bit, @paramlist nvarchar(max), @msg nvarchar(4000);
	exec @ok_to_log = logger.ok_to_log @level = 16;
	exec @verbose = logger.get_pref @pref_name = N'verbose';
	
	if (@ok_to_log = 1)
	begin
		select @paramlist = coalesce(@paramlist + N', ', N'') + name + N': ' + val from @params;
		insert into logger.logger_logs
		(
			time_stamp,
			[text],
			logger_level,
			scope,
			[session_id],
			[service_name],
			[user_name],
			client_identifier,
			params,
			extra
		)
		select
			sysdatetime(),
			@text,
			16,
			@scope,
			@@spid,
			@@servicename,
			suser_name(),
			db_name(),
			@paramlist,
			@extra;

		if (@verbose = 1)
		begin
			set @msg = concat(@scope, N' - ', @text);
			raiserror(@msg,0,1) with nowait;
		end;
	end;
end;
go


if object_id(N'logger.log_permanent', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_permanent]; 
end;
go
create procedure [logger].[log_permanent] 
(
	@text nvarchar(4000),
	@scope nvarchar(1000) = null,
	@params logger.logger_tab_param readonly,
	@extra nvarchar(max) = null
)
as
begin 
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @ok_to_log bit, @verbose bit, @paramlist nvarchar(max), @msg nvarchar(4000);
	exec @ok_to_log = logger.ok_to_log @level = 1;
	exec @verbose = logger.get_pref @pref_name = N'verbose';
	
	if (@ok_to_log = 1)
	begin
		select @paramlist = coalesce(@paramlist + N', ', N'') + name + N': ' + val from @params;
		insert into logger.logger_logs
		(
			time_stamp,
			[text],
			logger_level,
			scope,
			[session_id],
			[service_name],
			[user_name],
			client_identifier,
			params,
			extra
		)
		select
			sysdatetime(),
			@text,
			1,
			@scope,
			@@spid,
			@@servicename,
			suser_name(),
			db_name(),
			@paramlist,
			@extra;

		if (@verbose = 1)
		begin
			set @msg = concat(@scope, N' - ', @text);
			raiserror(@msg,0,1) with nowait;
		end;
	end;
end;
go


if object_id(N'logger.log_error', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_error]; 
end;
go
create procedure [logger].[log_error] 
(
	@text nvarchar(4000),
	@scope nvarchar(1000) = null,
	@params logger.logger_tab_param readonly,
	@extra nvarchar(max) = null
)
as
begin 
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @ok_to_log bit, @verbose bit, @paramlist nvarchar(max), @msg nvarchar(4000);
	exec @ok_to_log = logger.ok_to_log @level = 2;
	exec @verbose = logger.get_pref @pref_name = N'verbose';
	
	if (@ok_to_log = 1)
	begin
		select @paramlist = coalesce(@paramlist + N', ', N'') + name + N': ' + val from @params;
		insert into logger.logger_logs
		(
			time_stamp,
			[text],
			logger_level,
			scope,
			[session_id],
			[service_name],
			[user_name],
			client_identifier,
			params,
			extra,
			[error_line], 
			[error_message], 
			[error_number], 
			[error_procedure], 
			[error_severity],
			[error_state]
		)
		select
			sysdatetime(),
			@text,
			2,
			@scope,
			@@spid,
			@@servicename,
			suser_name(),
			db_name(),
			@paramlist,
			@extra,
			error_line(),
			error_message(),
			error_number(),
			error_procedure(),
			error_severity(),
			error_state()

		if (@verbose = 1)
		begin
			set @msg = concat(@scope, N' - ', @text, N' - ', error_message());
			raiserror(@msg,0,1) with nowait;
		end;
	end;
end;
go

if object_id(N'logger.log_information', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_information]; 
end;
go
create procedure [logger].[log_information] 
(
	@text nvarchar(4000),
	@scope nvarchar(1000) = null,
	@params logger.logger_tab_param readonly,
	@extra nvarchar(max) = null
)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @ok_to_log bit, @verbose bit, @paramlist nvarchar(max), @msg nvarchar(4000);
	exec @ok_to_log = logger.ok_to_log @level = 8;
	exec @verbose = logger.get_pref @pref_name = N'verbose';
	
	if (@ok_to_log = 1)
	begin
		select @paramlist = coalesce(@paramlist + N', ', N'') + name + N': ' + val from @params;
		insert into logger.logger_logs
		(
			time_stamp,
			[text],
			logger_level,
			scope,
			[session_id],
			[service_name],
			[user_name],
			client_identifier,
			params,
			extra
		)
		select
			sysdatetime(),
			@text,
			8,
			@scope,
			@@spid,
			@@servicename,
			suser_name(),
			db_name(),
			@paramlist,
			@extra;

		if (@verbose = 1)
		begin
			set @msg = concat(@scope, N' - ', @text);
			raiserror(@msg,0,1) with nowait;
		end;
	end;
end;
go


if object_id(N'logger.log_warning', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_warning]; 
end;
go
create procedure [logger].[log_warning] 
(
	@text nvarchar(4000),
	@scope nvarchar(1000) = null,
	@params logger.logger_tab_param readonly,
	@extra nvarchar(max) = null
)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @ok_to_log bit, @verbose bit, @paramlist nvarchar(max), @msg nvarchar(4000);
	exec @ok_to_log = logger.ok_to_log @level = 4;
	exec @verbose = logger.get_pref @pref_name = N'verbose';
	
	if (@ok_to_log = 1)
	begin
		select @paramlist = coalesce(@paramlist + N', ', N'') + name + N': ' + val from @params;
		insert into logger.logger_logs
		(
			time_stamp,
			[text],
			logger_level,
			scope,
			[session_id],
			[service_name],
			[user_name],
			client_identifier,
			params,
			extra
		)
		select
			sysdatetime(),
			@text,
			4,
			@scope,
			@@spid,
			@@servicename,
			suser_name(),
			db_name(),
			@paramlist,
			@extra;
	
		if (@verbose = 1)
		begin
			set @msg = concat(@scope, N' - ', @text);
			raiserror(@msg,0,1) with nowait;
		end;
	end;
end;
go


if object_id(N'logger.log_tran_debug', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_tran_debug]; 
end;
go
create procedure [logger].[log_tran_debug] 
(
	@text nvarchar(4000),
	@scope varchar(1000) = null,
	@params logger.logger_tab_param readonly,
	@extra nvarchar(max) = null
)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @ok_to_log bit, @verbose bit, @paramlist nvarchar(max), @msg nvarchar(4000);
	exec @ok_to_log = logger.ok_to_log @level = 16;
	exec @verbose = logger.get_pref @pref_name = N'verbose';
	
	if (@ok_to_log = 1)
	begin
		select @paramlist = coalesce(@paramlist + N', ', N'') + name + N': ' + val from @params;

		if (@verbose = 1)
		begin
			set @msg = concat(@scope, N' - ', @text);
			raiserror(@msg,0,1) with nowait;
		end;
		
		-- return to caller to be inserted into logger_tab_tran table type
		select
			16 as [logger_level],
			@text as [text],
			@scope as [scope],
			sysdatetime() as [time_stamp],
			@@spid as [session_id],
			@@servicename as [service_name],
			suser_name() as [user_name],
			db_name() as [client_identifier],
			null as [error_line],	
			null as [error_message],	
			null as [error_number],	
			null as [error_procedure],
			null as [error_severity],
			null as [error_state],
			@paramlist as [params],
			@extra as [extra];
	end;
end;
go


if object_id(N'logger.log_tran_error', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_tran_error]; 
end;
go
create procedure [logger].[log_tran_error] 
(
	@text nvarchar(4000),
	@scope varchar(1000) = null,
	@params logger.logger_tab_param readonly,
	@extra nvarchar(max) = null
)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @ok_to_log bit, @verbose bit, @paramlist nvarchar(max), @msg nvarchar(4000);
	exec @ok_to_log = logger.ok_to_log @level = 2;
	exec @verbose = logger.get_pref @pref_name = N'verbose';
	
	if (@ok_to_log = 1)
	begin
		select @paramlist = coalesce(@paramlist + N', ', N'') + name + N': ' + val from @params;
		
		if (@verbose = 1)
		begin
			set @msg = concat(@scope, N' - ', @text);
			raiserror(@msg,0,1) with nowait;
		end;

		-- return to caller to be inserted into logger_tab_tran table type
		select
			2 as [logger_level],
			@text as [text],
			@scope as [scope],
			sysdatetime() as [time_stamp],
			@@spid as [session_id],
			@@servicename as [service_name],
			suser_name() as [user_name],
			db_name() as [client_identifier],
			error_line() as [error_line],
			error_message() as [error_message],
			error_number() as [error_number],
			error_procedure() as [error_procedure],
			error_severity() as [error_severity],
			error_state() as [error_state],
			@paramlist as [params],
			@extra as [extra];
	end;
end;
go


if object_id(N'logger.log_tran_information', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_tran_information]; 
end;
go
create procedure [logger].[log_tran_information] 
(
	@text nvarchar(4000),
	@scope varchar(1000) = null,
	@params logger.logger_tab_param readonly,
	@extra nvarchar(max) = null
)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @ok_to_log bit, @verbose bit, @paramlist nvarchar(max), @msg nvarchar(4000);
	exec @ok_to_log = logger.ok_to_log @level = 8;
	exec @verbose = logger.get_pref @pref_name = N'verbose';
	
	if (@ok_to_log = 1)
	begin
		select @paramlist = coalesce(@paramlist + N', ', N'') + name + N': ' + val from @params;

		if (@verbose = 1)
		begin
			set @msg = concat(@scope, N' - ', @text);
			raiserror(@msg,0,1) with nowait;
		end;

		-- return to caller to be inserted into logger_tab_tran table type
		select
			8 as [logger_level],
			@text as [text],
			@scope as [scope],
			sysdatetime() as [time_stamp],
			@@spid as [session_id],
			@@servicename as [service_name],
			suser_name() as [user_name],
			db_name() as [client_identifier],
			null as [error_line],	
			null as [error_message],	
			null as [error_number],	
			null as [error_procedure],
			null as [error_severity],
			null as [error_state],
			@paramlist as [params],
			@extra as [extra];
	end;
end;
go


if object_id(N'logger.log_tran_warning', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_tran_warning]; 
end;
go
create procedure [logger].[log_tran_warning] 
(
	@text nvarchar(4000),
	@scope varchar(1000) = null,
	@params logger.logger_tab_param readonly,
	@extra nvarchar(max) = null
)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;

	declare @ok_to_log bit, @verbose bit, @paramlist nvarchar(max), @msg nvarchar(4000);
	exec @ok_to_log = logger.ok_to_log @level = 4;
	exec @verbose = logger.get_pref @pref_name = N'verbose';
	
	if (@ok_to_log = 1)
	begin
		select @paramlist = coalesce(@paramlist + N', ', N'') + name + N': ' + val from @params;

		if (@verbose = 1)
		begin
			set @msg = concat(@scope, N' - ', @text);
			raiserror(@msg,0,1) with nowait;
		end;

		-- return to caller to be inserted into logger_tab_tran table type
		select
			4 as [logger_level],
			@text as [text],
			@scope as [scope],
			sysdatetime() as [time_stamp],
			@@spid as [session_id],
			@@servicename as [service_name],
			suser_name() as [user_name],
			db_name() as [client_identifier],
			null as [error_line],	
			null as [error_message],	
			null as [error_number],	
			null as [error_procedure],
			null as [error_severity],
			null as [error_state],
			@paramlist as [params],
			@extra as [extra];
	end;
end;
go


if object_id(N'logger.log_tran_flush', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_tran_flush]; 
end;
go
create procedure [logger].[log_tran_flush] 
(
	@logs_in_tran logger.logger_tab_tran readonly
)
as
begin
	set nocount on;
	set transaction isolation level read uncommitted;
	
	insert into [logger].[logger_logs]
	(
		[logger_level],
		[text],
		[scope],
		[time_stamp],
		[session_id],
		[service_name],
		[user_name],
		[client_identifier],
		[error_line],	
		[error_message],	
		[error_number],	
		[error_procedure],
		[error_severity],
		[error_state],
		[params],
		[extra]
	)
	select
		[logger_level],
		[text],
		[scope],
		[time_stamp],
		[session_id],
		[service_name],
		[user_name],
		[client_identifier],
		[error_line],	
		[error_message],	
		[error_number],	
		[error_procedure],
		[error_severity],
		[error_state],
		[params],
		[extra]
	from @logs_in_tran;
end;
go


if object_id(N'logger.purge', N'P') IS NOT NULL
begin
	drop procedure [logger].[purge]; 
end;
go
create procedure [logger].[purge]
(
	@purge_after_days int = null,
	@purge_min_level nvarchar(50) = null
)
as
begin
	set nocount on;

	declare @lpurge_after_days int,
		@lpurge_min_level int;
	
	if @purge_after_days is null
		select @lpurge_after_days = convert(int,pref_value)
		from logger.logger_prefs where pref_name = N'PURGE_AFTER_DAYS';
	else
		set @lpurge_after_days = @purge_after_days;

	if @purge_min_level is null
		select @lpurge_min_level = case pref_value
			when N'OFF'		then 0
			when N'PERMANENT'	then 1
			when N'ERROR'		then 2
			when N'WARNING'		then 4
			when N'INFORMATION'	then 8
			when N'DEBUG'		then 16
		end from logger.logger_prefs 
		where pref_name = N'PURGE_MIN_LEVEL';
	else
		set @lpurge_min_level = case @purge_min_level
			when N'OFF'		then 0
			when N'PERMANENT'	then 1
			when N'ERROR'		then 2
			when N'WARNING'		then 4
			when N'INFORMATION'	then 8
			when N'DEBUG'		then 16 end;
	
	delete from [logger].[logger_logs]
	where logger_level >= @lpurge_min_level
		and time_stamp < dateadd(day, @lpurge_after_days, sysdatetime())
        	and logger_level > 1;
end;
go


if object_id(N'logger.purge_all', N'P') is not null
begin
	drop procedure [logger].[purge_all]; 
end;
go

create procedure [logger].[purge_all]
as
begin
	set nocount on;
	delete from logger.logger_logs
	where logger_level > 1;
end;
go
raiserror(N'Logger Procedures Installed',0,1) with nowait;



-- Create Logger Purge Job
-----------------------------------------------------------------------------------------
declare 
	@job nvarchar(100) = DB_NAME() + N'_logger_purge_job',
	@db nvarchar(50) = DB_NAME(),
	@jobId binary(16);

--delete job if exists
select @jobId = job_id from msdb.dbo.sysjobs where (name = @job)
if (@jobId IS NOT NULL)
begin
	exec msdb.dbo.sp_delete_job @jobId
end;

--Add a job
exec msdb.dbo.sp_add_job 
	@job_name = @job;

--Add a job step named process step. This step runs the stored procedure
exec msdb.dbo.sp_add_jobstep
	@job_name = @job,
	@step_name = N'process step',
	@subsystem = N'TSQL',
	@database_name = @db,
	@command = N'logger.purge';

--Schedule the job at a specified date and time
exec msdb.dbo.sp_add_jobschedule 
	@job_name = @job,
	@name = N'logger_purge_schedule',
	@freq_type = 8, --weekly
	@freq_interval = 64, -- Saturday
	@freq_recurrence_factor = 1, -- every week
	@active_start_time = 20000; -- 2:00 AM

-- Add the job to the SQL Server Server
exec msdb.dbo.sp_add_jobserver
	@job_name =  @job;

raiserror(N'Logger Purge Job Installed',0,1) with nowait;


-- Finish
exec logger.log_permanent 
	@text = N'Installed T-SQL Logger', 
	@scope = N'Logger Installation Script Test';

raiserror(N'Installation Completed',0,1) with nowait;
