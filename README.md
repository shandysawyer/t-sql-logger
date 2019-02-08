# T-SQL Logger

## Overview
T-SQL Logger is SQL Server logging framework for use with stored procedures. It is intended to help with: 
- Profiling execution time
- Researching performance issues 
- Debugging unhandled errors 
- Logging errors caused by circumstantial data not covered during unit testing
- Logging production database execution where profilers are restricted

## Documentation
- [Installation](docs/installation.md)
- [API](docs/api.md)
- [Best Practices](docs/best%20practices.md)

## License
This project is uses the [MIT license](LICENSE).

## Credit
This logger solution was inspired by the OraOpenSource Logger http://www.oraopensource.com/logger/. Their API along with some implementation details were adopted under permission of their MIT License.
