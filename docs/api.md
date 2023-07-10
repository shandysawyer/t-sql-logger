# API
## Main Logger Procedures
Since the main Logger procedures all have the same syntax and behavior (except for the procedure names) the documentation has been combined to avoid replication.
 
### Syntax
```sql
log_[level] (
  @text nvarchar(4000),
  @scope nvarchar(1000) = null,
  @params dbo.logger_tab_param readonly,
  @extra nvarchar(max) = null
);
```

### Parameters
Parameter| Description
------------ | -------------
@text	| maps to the `text` column in `logger_logs`. Can be used to describe the operation is about to execute, has finished execution,  the state of variables, etc.
@scope	| scope is optional but highly recommend. The idea behind scope is to give some context to the log message, such as the database, schema and/or procedure where it was called.
@params	| params is for storing any method parameters passed into the procedure. Each parameter name/value pair will be comma delimted like so: “param1: val, param2: val, ... ”.
@extra | extra is used when you may have extra elements to capture. This was originally introduced to help capture resulting generated dynamic SQL from other processes during execution. The extra designation was applied for any other unforeseen items not thought of to be stored here as well.
 
### Examples
The following code snippet highlights the main Logger procedures. Since they all have the same parameters, this will serve as the general example for all the main Logger procedures.
```sql
exec logger.log_debug @text = 'This is a debug message. (level = DEBUG)';
exec logger.log_information @text = 'This is an informational message. (level = INFORMATION)';
exec logger.log_warning @text = 'This is a warning message. (level = WARNING)';
exec logger.log_error @text = 'This is an error message (level = ERROR)';
exec logger.log_permanent @text = 'This is a permanent message, good for upgrades and milestones. (level = PERMANENT)';
```
 
## Method Descriptions
### LOG_DEBUG
This procedure will log an entry into the LOGGER_LOGS table when the logger_level is set to "DEBUG" in the logger_prefs table.
 
### LOG_INFORMATION
This procedure will log an entry into the LOGGER_LOGS table when the logger_level is set to "INFORMATION" in the logger_prefs table.
 
### LOG_WARNING
This procedure will log an entry into the LOGGER_LOGS table when the logger_level is set to "WARNING" in the logger_prefs table. 
 
### LOG_ERROR
This procedure will log an entry into the LOGGER_LOGS table when the logger_level is set to "ERROR" in the logger_prefs table. This procedure should only be used inside a catch block.
 
### LOG_PERMANENT
This procedure will log an entry into the LOGGER_LOGS table when the logger_level is set to "PERMANENT" in the logger_prefs table. These logs are permanent and will not be deleted when executing purge or purge_all procedures.
 
### LOG_TRAN_DEBUG
This procedure is meant to be used in conjunction with transactions. The procedure will return data which is then mean to be inserted into a table variable of type logger.logger_tab_tran. To complete the process, logger.log_tran_flush must be called otherwise the data will be lost. This will only log when the logger_level is set to "DEBUG" in the logger_prefs table.
 
### LOG_TRAN_INFORMATION
This procedure is meant to be used in conjunction with transactions. The procedure will return data which is then mean to be inserted into a table variable of type logger.logger_tab_tran. To complete the process, logger.log_tran_flush must be called otherwise the data will be lost. This will only log when the logger_level is set to "INFORMATION" in the logger_prefs table.
 
### LOG_TRAN_WARNING
This procedure is meant to be used in conjunction with transactions. The procedure will return data which is then mean to be inserted into a table variable of type logger.logger_tab_tran. To complete the process, logger.log_tran_flush must be called otherwise the data will be lost. This will only log when the logger_level is set to "WARNING" in the logger_prefs table.
 
### LOG_TRAN_ERROR
This procedure is meant to be used in conjunction with transactions. The procedure will return data which is then mean to be inserted into a table variable of type logger.logger_tab_tran. To complete the process, logger.log_tran_flush must be called otherwise the data will be lost. This will only log when the logger_level is set to "ERROR" in the logger_prefs table. This procedure should only be used inside a catch block.
 
### LOG_TRAN_FLUSH
This procedure is called to flush the data from the table variable of type logger.logger_tab_tran that is collecting data during a transaction into the logger_logs table. See Best Practices for reference on usage.

### PURGE
Deletes all non-permanent entries older than X days for a given logger level and above in the logger_logs table
 
#### Syntax
```sql
exec logger.purge(
  @purge_after_days int = null,
  @purge_min_level varchar(50) = null
  );
```

#### Parameters
Parameter |	Description
------------ | -------------
purge_after_days | Purge entries older than n days. If left NULL then the value from the logger_prefs table is used by default.
purge_min_level	| Minimum level to purge entries. For example if set to "INFORMATION" then information and debug will be deleted. If left NULL then the value from the logger_prefs table is used by default.
 
### PURGE_ALL
Deletes all non-permanent entries in the logger_logs table.
 
#### Syntax
```sql
exec logger.purge_all;
```
