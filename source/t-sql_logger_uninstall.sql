-----------------------------------------------------------------------------------------
-- T-SQL Logger Uninstall
-----------------------------------------------------------------------------------------

raiserror(N'T-SQL Logger',0,1) with nowait;
raiserror(N'Uninstall Started...',0,1) with nowait;
set nocount on;


-- Drop Logger Purge Job
-----------------------------------------------------------------------------------------
declare 
	@job nvarchar(100) = db_name() + N'_logger_purge_job',
	@jobId binary(16);

--delete job if exists
select @jobId = job_id from msdb.dbo.sysjobs where (name = @job)
if (@jobId IS NOT NULL)
begin
    exec msdb.dbo.sp_delete_job @jobId
end;

raiserror(N'Logger Purge Job Deleted',0,1) with nowait;


-- Drop Procedures
-----------------------------------------------------------------------------------------
if object_id(N'logger.log_debug', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_debug] 
end;
go

if object_id(N'logger.log_permanent', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_permanent]; 
end;
go

if object_id(N'logger.log_error', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_error]; 
end;
go

if object_id(N'logger.log_information', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_information]; 
end;
go

if object_id(N'logger.log_warning', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_warning]; 
end;
go

if object_id(N'logger.log_tran_debug', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_tran_debug]; 
end;
go

if object_id(N'logger.log_tran_error', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_tran_error]; 
end;
go

if object_id(N'logger.log_tran_information', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_tran_information]; 
end;
go

if object_id(N'logger.log_tran_warning', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_tran_warning]; 
end;
go

if object_id(N'logger.log_tran_flush', N'P') IS NOT NULL
begin
	drop procedure [logger].[log_tran_flush]; 
end;
go

if object_id(N'logger.purge', N'P') IS NOT NULL
begin
	drop procedure [logger].[purge]; 
end;
go

if object_id(N'logger.purge_all', N'P') is not null
begin
	drop procedure [logger].[purge_all]; 
end;
go
raiserror(N'Procedures Dropped',0,1) with nowait;


-- Drop Functions
-----------------------------------------------------------------------------------------
if object_id(N'logger.ok_to_log', N'FN') IS NOT NULL
begin
	drop function [logger].[ok_to_log];
end;
go

if object_id(N'logger.get_pref', N'FN') IS NOT NULL
begin
	drop function [logger].[get_pref];
end;
go
raiserror(N'Functions Dropped',0,1) with nowait;


-- Drop Types
-----------------------------------------------------------------------------------------
if type_id(N'logger.logger_tab_param') is not null
begin
	drop type logger.logger_tab_param;
end;
go


if type_id(N'logger.logger_tab_tran') is not null
begin
	drop type logger.logger_tab_tran;
end;
go
raiserror(N'Types Dropped',0,1) with nowait;


-- Drop Tables
-----------------------------------------------------------------------------------------
if object_id(N'logger.logger_logs', N'U') is not null
begin
	drop table logger.logger_logs 
end;
go

if object_id(N'logger.logger_prefs', N'U') is not null
begin
	drop table logger.logger_prefs
end;
go
raiserror(N'Tables Dropped',0,1) with nowait;


-- Create Schema
-----------------------------------------------------------------------------------------
if not exists (select name from sys.schemas where name = N'logger')
begin
      exec('drop schema [logger]');
	  raiserror(N'Schema Dropped',0,1) with nowait;
end;


-- Finished
-----------------------------------------------------------------------------------------
raiserror(N'T-SQL Logger Uninstall Complete',0,1) with nowait;
