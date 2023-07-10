# Best Practices

## Logging in a Stored Procedure
```sql
create procedure [dbo].[test_proc]
as
begin
	set xact_abort, nocount on;

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
	set xact_abort, nocount on;

	begin try
		declare @obj_name nvarchar(128) = object_schema_name(@@procid) + '.' + object_name(@@procid),
			@params as logger.logger_tab_param,
			@log_text nvarchar(4000);

		-- log procedure parameters
		insert into @params (name, val) 
		values('id', convert(varchar(10), @id)), ('value', @value);

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
		declare @obj_name nvarchar(128) = object_schema_name(@@procid) + '.' + object_name(@@procid),
			@params as logger.logger_tab_param,
			@log as logger.logger_tab_tran,
			@log_text nvarchar(4000);

		-- log that our procedure has started
		exec logger.log_information 'Executing', @obj_name, @params;

		-- begin our unit of work
		begin transaction;

		-- logger has specific transaction methods that returns a dataset to be inserted into a logging table variable.
		-- table variables live outside of transactions and the log information won't be lost should any operations fail.
		insert into @log exec logger.log_tran_information 'Transaction started', @obj_name, @params;

		-- do important business work
		insert into test_table select 1, 'Test';
		set @log_text = 'Inserted ' + convert(varchar(10), @@rowcount) + ' row(s) into test_table in transaction';
		insert into @log exec logger.log_tran_debug @log_text, @obj_name, @params;

		-- complete our unit of work
		commit transaction;

		-- this will flush all accumulated logger calls in the table variable into the logger_logs table
		exec logger.log_tran_flush @log;

		-- log that the procedure has finished
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
			exec logger.log_tran_flush @log;
		end
		else
			exec logger.log_error 'Unhandled Exception', @obj_name, @params;

		-- rethrow the exception to the caller
		throw;
	end catch;
end;
```

## Logging in Functions
SQL Server does not allow procedure excution inside of User Defined Functions. As a work-around, the logger procedures could be executed in a calling procedure. This could be overkill in certain scenarios, but if your function is returning data from a complex query you are concerned about, it could be worth the added code overhead.

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
	set xact_abort, nocount on;

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
