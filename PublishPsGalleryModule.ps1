#requires -Modules PowerShellGet


$ReleaseNotes =@'

IPv6Regex

Chris Warwick, @cjwarwickps, October 2015

This PowerShell script tests a number of regular expressions that match text representations of IPv6 addresses.  
The script also runs the sample test cases against the [System.Net.IpAddress]::TryParse() method to illustrate 
some subtle considerations with address validation.

See the comments at the end of the script file for further detailed notes and references.

Script Structure
----------------

This script is split into four sections:

1. The first section defines an IPv6 regex to the tested against a set of sample addresses. A number of other 
Regexs gathered from across the web are also defined here.  
   
2. Following the regex definitions, an array of test script-blocks is defined.  Each script block takes a test 
IPv6 address as a parameter and tests this address against a specific regex or against the IpAddress.TryParse() 
method.  The script blocks return true if the address is considered valid by the test or false otherwise.

3. The next (largest) section of the script defines sample IPv6 addresses to be tested. There are a large number 
of both valid and invalid address representations defined.
   
4. The final section of the script runs the tests. Each test script block is selected in turn and the test 
addresses are matched against the script blocks. Each test returns a test result object containing details of the 
individual test.  The tests are timed to allow comparison of the performance of each test method (use the -Verbose 
switch to view timings).

**NOTE**: The output of this script is most useful as a consolidated report.  Consequently, the script 'breaks the 
rules' somewhat by including output formatting.  This behaviour can be changed by specifying the '-NoFormat' 
switch parameter to instruct the script to pass test-result objects to the output pipeline (these can then be 
formatted or collected as required).


Results
-------

Unsurprisingly, a number of regexs found on the web are invalid (only one is included here, others have been 
omitted).  Beware of using random regexs without testing them.

There are some subtleties with the operation of the IpAddress.TestParse() method:

1. The IpAddress.TryParse() methods allow leading zeroes in the IPv4 octets.  This is actually explicitly invalid 
in the definition in rfc3986 (apparently some systems(?) use a leading zero to denote an Octal number in the IPv4 
Octet).

2. The IpAddress::TryParse method does not accept leading elided-zeroes syntax: ('::....')  if there is only one 
group (the first group) of the address mising - although this is valid according to the RFC. So, for example, 
::2:3:4:5:6:7 is considered valid by IpAddress.TryParse(), but ::2:3:4:5:6:7:8 isn't

3. The IpAddress.TryParse() method by default accepts IPv4 addresses; these can be qualified by checking the 
address against the [System.Net.Sockets.AddressFamily]::InterNetworkV6 type

Compiling regexs is an expensive operation, and even for the relatively large number of tests defined here it can 
be seen from the timing information that the investment is not warranted in this case.

Although the IpAddress.TryParse() method has some idiosyncrasies it may be preferred to the regex matching methods 
given the complexity of these regexs (IpAddress.TryParse() is probably equally as complex but the at least the 
complexity is hidden :-)

Script Help
-----------
````

<#
.SYNOPSIS
   Tests IPv6 Regex patterns against a large number of sample test addresses. 
.DESCRIPTION
   This function tests a number of IPv6 regexs against a selection of valid and invalid
   IPv6 addresses to verify that the regexs perform as expected.  The function also tests
   the sample addresses using the [System.Net.IpAddress]::TryParse() method to illustrate
   the performance and conformance of this method.
.NOTES
   The script will time the relative performance of the various regexs; use the -Verbose
   switch to display the timimg information.
.PARAMETER TestName
   If specified, only run tests with names matching this.
.PARAMETER NoFormat
   Provide raw output objects for each test.  The default is to select only failing test
   result objects and to format the resulting output.  Use this parameter if you wish to 
   use a different selection or formatting option to the default provided here.
.EXAMPLE
   IPv6Regex
   Run all tests and display those that fail.
.EXAMPLE
   IPv6Regex -Verbose
   Run all tests; additionally display relative performance timings.
.EXAMPLE
   IPv6Regex -TestName 'compiled'
   Only run tests where the test name includes the string 'compiled'.
.EXAMPLE
   IPv6Regex -NoFormat
   Run all tests and output a raw RegexMatchResult object for each test.
.INPUTS
   None
.OUTPUTS
   By default, outputs formated table of failing tests.  Use -NoFormat to output raw objects.
.FUNCTIONALITY
   Test IPv6 Regexs against sample IPv6 Addresses.
.LINK
   http://github.com/ChrisWarwick/IPv6Regex
#>


````


Sample Output
-------------
**Note:** By default the script will only output results of failed tests (use the -NoFormat parameter to change 
this behaviour).  As illustrated below, use the -Verbose switch to display relative timing information.

````

PS:\> Import-Module IPv6Regex
PS:\> IPv6Regex -Verbose
VERBOSE:  0 of 470 unique tests failed in   75ms for 'IPv6 Regex'
VERBOSE:  0 of 470 unique tests failed in  174ms for 'Compiled IPv6 Regex'
VERBOSE: 19 of 470 unique tests failed in   88ms for 'Php1'
VERBOSE:  0 of 470 unique tests failed in   98ms for 'RegexBuddy'
VERBOSE:  0 of 470 unique tests failed in  142ms for 'Compiled RegexBuddy'
VERBOSE: 11 of 470 unique tests failed in  120ms for 'Net IpAddress TryParse() Method'
VERBOSE:  8 of 470 unique tests failed in  180ms for 'Qualified Net IpAddress TryParse() Method'
VERBOSE:  0 of 470 unique tests failed in  202ms for 'Aeron Regex'

TestName                                  TestAddress                                   ExpectedResult ActualResult
--------                                  -----------                                   -------------- ------------
Php1                                      ::0:0:0:0:0:0:0                                         True        False
Php1                                      ::0:a:b:c:d:e:f                                         True        False
Php1                                      ::2:3:4:5:6:7:8                                         True        False
Php1                                      ::2222:3333:4444:5555:6666:123.123.123.123              True        False
Php1                                      ::2222:3333:4444:5555:6666:7777:8888                    True        False
Php1                                      :1.2.3.4                                               False         True
Php1                                      :10.0.0.1                                              False         True
Php1                                      :2222:3333:4444:5555:6666:1.2.3.4                      False         True
Php1                                      :3333:4444:5555:6666:1.2.3.4                           False         True
Php1                                      :4444:5555:6666:1.2.3.4                                False         True
Php1                                      :5555:6666:1.2.3.4                                     False         True
Php1                                      :6666:1.2.3.4                                          False         True
Php1                                      0:0:0:0:0:0:0::                                         True        False
Php1                                      0:a:b:c:d:e:f::                                         True        False
Php1                                      1111:2222:3333:4444:5555:6666:00.00.00.00              False         True
Php1                                      1111:2222:3333:4444:5555:6666:000.000.000.000          False         True
Php1                                      1111:2222:3333:4444:5555:6666:7777::                    True        False
Php1                                      a:b:c:d:e:f:0::                                         True        False
Php1                                      fe80:0000:0000:0000:0204:61ff:254.157.241.086          False         True
Net IpAddress TryParse() Method           ::0:0:0:0:0:0:0                                         True        False
Net IpAddress TryParse() Method           ::0:a:b:c:d:e:f                                         True        False
Net IpAddress TryParse() Method           ::2:3:4:5:6:7:8                                         True        False
Net IpAddress TryParse() Method           ::2222:3333:4444:5555:6666:123.123.123.123              True        False
Net IpAddress TryParse() Method           ::2222:3333:4444:5555:6666:7777:8888                    True        False
Net IpAddress TryParse() Method           1.2.3.4                                                False         True
Net IpAddress TryParse() Method           1111                                                   False         True
Net IpAddress TryParse() Method           1111:2222:3333:4444:5555:6666:00.00.00.00              False         True
Net IpAddress TryParse() Method           1111:2222:3333:4444:5555:6666:000.000.000.000          False         True
Net IpAddress TryParse() Method           123                                                    False         True
Net IpAddress TryParse() Method           fe80:0000:0000:0000:0204:61ff:254.157.241.086          False         True
Qualified Net IpAddress TryParse() Method ::0:0:0:0:0:0:0                                         True        False
Qualified Net IpAddress TryParse() Method ::0:a:b:c:d:e:f                                         True        False
Qualified Net IpAddress TryParse() Method ::2:3:4:5:6:7:8                                         True        False
Qualified Net IpAddress TryParse() Method ::2222:3333:4444:5555:6666:123.123.123.123              True        False
Qualified Net IpAddress TryParse() Method ::2222:3333:4444:5555:6666:7777:8888                    True        False
Qualified Net IpAddress TryParse() Method 1111:2222:3333:4444:5555:6666:00.00.00.00              False         True
Qualified Net IpAddress TryParse() Method 1111:2222:3333:4444:5555:6666:000.000.000.000          False         True
Qualified Net IpAddress TryParse() Method fe80:0000:0000:0000:0204:61ff:254.157.241.086          False         True



 Version History:

 V1.1.1 (This version)
  - Updated inline help and Readme

 V1.0 (Original Published Version)
  - Initial release to the PowerShell Gallery and TechNet Script Center

 V0.1-0.9 Dev versions


'@

$Tags = @(
   'Regex'
   'PowerShell'
   'IPv6'
   'IpAddress'
   'Network'
   'Address'
   'rfc4291'
   'rfc5952'
   'rfc3986'
   'rfc4007'
)

$PublishParams = @{
    Name            = 'IPv6Regex'
    NuGetApiKey     = 'XXXXRedactedXXXX'
    ReleaseNotes    = $ReleaseNotes
    Tags            = $Tags
    ProjectUri      = 'https://github.com/ChrisWarwick/IPv6Regex'
}



Publish-Module @PublishParams


# ...later

# Find-Module IPv6Regex
