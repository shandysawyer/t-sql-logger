# Best Practices

## Logging in a Stored Procedure
```sql
create procedure [dbo].[test_proc]
as
begin
	-- get name of the object in scope
	declare @obj_name nvarchar(128) = object_schema_name(@@procid) + '.' + object_name(@@procid);

	begin try
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
	-- log method parameters here
	declare @params as logger.logger_tab_param;
	insert into @params (name, val) 
	values('id', convert(varchar(10), @id)),
		('value', @value);

	-- method name here
	declare @obj_name nvarchar(128) = object_schema_name(@@procid) + '.' + object_name(@@procid);
	declare @log_text nvarchar(4000);

	begin try
		-- log the start of the proc
		exec logger.log_information 'Executing', @obj_name, @params;

		insert into test_table select @id, @value;

		-- sql server doesn't allow expressions as parameter arguments, so place into variable
		set @log_text = 'Inserted ' + convert(varchar(10),@@rowcount) + ' row(s) into test_table';
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

	-- get name of the object in scope
	declare @obj_name nvarchar(128) = object_schema_name(@@procid) + '.' + object_name(@@procid);

	-- table variables live outside of transactions
	declare @params as logger.logger_tab_param;
	declare @log as logger.logger_tab_tran;

	begin try
		exec logger.log_information 'Executing', @obj_name, @params;

		exec logger.log_debug 'Do some work here', @obj_name, @params;

		-- begin our unit of work
		begin transaction;

		-- here we need to log with a different method than normal
		-- the data is passed of out of the procedure and is collected into the table variable
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
			insert into @log exec logger.log_tran_error 'Unhandled exception in transaction', @obj_name, @params;
			rollback transaction;
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
SQL Server does not allow calls to procedures inside of User Defined Functions. As such we cannot log functions from inside of them. However, a call can be made to logger surrounding the function call in same scope (such as inside the calling procedure). This could be overkill in certain scenarios, but if your function is returning data from a complex query you are concerned about, it could be worth the added code overhead.
```sql
create function [dbo].[test_func]( @id int ) returns int
as
begin
	return @id;
end;
go

create procedure [dbo].[call_proc]
as
begin
	-- get name of the object in scope
	declare @obj_name nvarchar(128) = object_schema_name(@@procid) + '.' + object_name(@@procid),
		@result int;

	begin try
		-- log the start of the proc
		exec logger.log_information 'Executing', @obj_name;

		-- set the scope to the function you're going to call
		set @obj_name = 'dbo.test_func';

		-- Executing the function
		exec logger.log_information 'Executing', @obj_name;
		set @result = [dbo].[test_func](1);
		exec logger.log_information 'Finished', @obj_name;

		-- set the scope back to the caller
		set @obj_name = object_schema_name(@@procid) + '.' + object_name(@@procid)

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
