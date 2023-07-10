# Best Practices

## Logging in a Stored Procedure
```sql
create procedure [dbo].[test_proc]
as
begin
	set xact_abort, no_count on;

	begin try
		-- get name of the object in scope
		declare @obj_name nvarchar(128) = object_schema_name(@@procid) + '.' + object_name(@@procid);

		-- log the start of the proc
		exec logger.log_information 'Executing', @obj_name;

		-- Do work in the procedure here and log it at a different level
		exec logger.log_debug 'Do intensive work here', @obj_name;

		-- log the end of the proc
		exec logger.log_information 'Finished', @obj_name;
	end try
	begin catch
		-- log any exceptions that may occur
		exec logger.log_error 'Unhandled Exception', @obj_name;
		-- rethrow the exception
		throw;
	end catch;
end;
```

## Logging a Stored Procedure with Parameters
```sql
create procedure [dbo].[test_proc_w_params] ( @id int, @value varchar(10) )
as
begin
	set xact_abort, no_count on;

	begin try
		-- log procedure parameters
		declare @params as logger.logger_tab_param;
		insert into @params (name, val) 
		values('id', convert(varchar(10), @id)),
			('value', @value);
	
		-- get procedure name
		declare @obj_name nvarchar(128) = object_schema_name(@@procid) + '.' + object_name(@@procid);
		declare @log_text nvarchar(4000);

		-- log the start of the procedure
		exec logger.log_information 'Executing', @obj_name, @params;

		insert into test_table select @id, @value;
		set @log_text = 'Inserted ' + convert(varchar(10), @@rowcount) + ' row(s) into test_table';
		exec logger.log_debug @log_text, @obj_name, @params;

		-- log the end of the proc
		exec logger.log_information 'Finished', @obj_name, @params;
	end try
	begin catch
		-- log any exceptions that may occur
		exec logger.log_error 'Unhandled Exception', @obj_name, @params;
		-- rethrow the exception
		throw;
	end catch;
end;
```
 
## Logging in a Stored Procedure with Transactions
```sql
create procedure [dbo].[test_proc_with_transaction]
as
begin
	set xact_abort, nocount on;

	begin try
		-- get name of the object in scope
		declare @obj_name nvarchar(128) = object_schema_name(@@procid) + '.' + object_name(@@procid);
	
		-- table variables live outside of transactions
		declare @params as logger.logger_tab_param;
		declare @log as logger.logger_tab_tran;

		exec logger.log_information 'Executing', @obj_name, @params;

		-- begin our unit of work
		begin transaction;

		-- here we need to log with a different method than normal
		-- the data is passed out of the log_tran_debug procedure and is collected into the table variable
		insert into @log exec logger.log_tran_debug 'Do intensive work here', @obj_name, @params;

		-- simulate error
		select 1/0;

		insert into @log exec logger.log_tran_debug 'Do more intensive work here', @obj_name, @params;

		commit transaction;

		-- this will move the data accumulated from the table variable into the logger_logs table
		exec logger.log_tran_finalize @log;

		exec logger.log_information 'Finished', @obj_name, @params;
	end try
	begin catch
		if (@@trancount > 0)
		begin
			-- rollback the transaction first otherwise subsequent error logging will fail
			rollback transaction;
			-- log the error
			insert into @log exec logger.log_tran_error 'Unhandled exception in transaction', @obj_name, @params;
			-- flush all logs from the table variable into the log table otherwise it will be lost
			exec logger.log_tran_finalize @log;
		end
		else
			exec logger.log_error 'Unhandled Exception', @obj_name, @params;

		-- rethrow the exception to the caller
		throw;
	end catch;
end;
```

## Logging in Functions
SQL Server does not allow procedure excution inside of User Defined Functions, so the log functions cannot be excuted inside of them. To get around this, the logger methods could be executed in a calling procedure. This could be overkill in certain scenarios, but if your function is returning data from a complex query you are concerned about, it could be worth the added code overhead.

```sql
create function [dbo].[test_func]( @id int )
returns int
as
begin
	return @id;
end;
go

create procedure [dbo].[call_proc]
as
begin
	set xact_abort, no_count on;

	begin try
		-- get name of the object in scope
		declare @obj_name nvarchar(128) = object_schema_name(@@procid) + '.' + object_name(@@procid),
		@result int;

		-- log the start of the proc
		exec logger.log_information 'Executing', @obj_name;

		-- Executing the function
		exec logger.log_information 'Executing', 'dbo.test_func';
		set @result = [dbo].[test_func](1);
		exec logger.log_information 'Finished', 'dbo.test_func';

		-- log the end of the proc
		exec logger.log_information 'Finished', @obj_name;
	end try
	begin catch
		-- log any exceptions that may occur
		exec logger.log_error 'Unhandled Exception', @obj_name;
		-- rethrow the exception
		throw;
	end catch;
end;
```
