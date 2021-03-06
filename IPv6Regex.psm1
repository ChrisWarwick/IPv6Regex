<# 

IPv6-Regex
Chris Warwick, @cjwarwickps, October 2015

This PowerShell script tests a number of regular expressions that match
text representations of IPv6 addresses.  The script also runs the sample
test cases against the [System.Net.IpAddress]::TryParse() method to illustrate
some subtle considerations with address validation.

See the end of the script for further notes.

Script Structure
----------------

This script is split into four sections:

1. The first section defines an IPv6 regex to the tested against a set of sample addresses.
   A number of other Regexs gathered from across the web are also defined here.  
   
2. Following the regex definitions, an array of test script-blocks is defined.  Each script
   block takes a test IPv6 address as a parameter and tests this address against a specific
   regex or against the IpAddress.TryParse() method.  The script blocks return true if the
   address is considered valid by the test or false otherwise.

3. The next (largest) section of the script defines sample IPv6 addresses to be tested. There
   are a large number of both valid and invalid address representations defined.
   
4. The final section of the script runs the tests. Each test script block is selected in turn 
   and the test addresses are matched against the script blocks. Each test returns a test 
   result object containing details of the individual test.  The tests are timed to allow 
   comparison of the performance of each test method (use the -Verbose switch to view timings).

NOTE: The output of this script is most useful as a consolidated report.  Consequently, the 
script 'breaks the rules' somewhat by including output formatting.  This behaviour can be
changed by specifying the '-NoFormat' switch parameter to instruct the script to pass test-
result objects to the output pipeline (these can then be formatted or collected as required).


Results
-------

Unsurprisingly, a number of regexs found on the web are invalid (only one is included here, 
others have been omitted).  Beware of using random regexs without testing them.

There are some subtleties with the operation of the IpAddress.TestParse() method.

1. Both the regex and the IpAddress.TryParse() methods allow leading zeroes in the IPv4 octets.  This is
actually explicitly invalid in the definition in rfc3986 (apparently some systems (?) use a leading zero
to denote an Octal number in the IPv4 Octet).

2. The IpAddress::TryParse method does not accept leading elided-zeroes syntax: ('::....')  if there is
only one group (the first group) of the address mising - although this is valid according to the RFC. So, 
for example, ::2:3:4:5:6:7 is considered valid by IpAddress::TryParse, but ::2:3:4:5:6:7:8 isn't

3. The IpAddress.TryParse() method by default accepts IPv4 addresses; these are qualified (filtered out)
by checking the address against the [System.Net.Sockets.AddressFamily]::InterNetworkV6 type

Compiling regexs is an expensive operation, and even for the relatively large number of tests defined
here the investment is not warranted.

Although the IpAddress.TryParse() method has some idiosyncrasies it may be preferred to the regex matching
methods given the complexity of these regexs (IpAddress.TryParse is probably equally as complex but the 
complexity is at least hidden :-)

#>

Function IPv6Regex { 

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

[OutputType('RegexMatchResult')]
[CmdletBinding()]
Param (
    $TestName,             # Only run tests with names matching this (default = run all tests)
    [Switch]$NoFormat      # Don't format the output (just retun TestResult objects)
)


    #region Script Section 1.  IPv6 Address Regexs.
    # Some of these regexs are also compiled in order to compare performance

    # IPv6 addresses are comprised of groups of 1-4 Hex digits:
    $Hex = '[0-9a-f]{1,4}'         # 1-4 hex characters (note: regex pattern is not case sensitive by default so "A-F" not included)

    # IPv6 addresses can have an embedded IPv4 address in the last 4 bytes.  This regex matches IPv4 if present:
    # Component parts of an IPv4 Address Octet:

    ${250-255} = '25[0-5]'     # Matches 3 digit numbers between 250 and 255
    ${200-249} = '2[0-4]\d'    # Matches 3 digit numbers between 200 and 249
    ${100-199} = '1\d\d'       # Matches 3 digit numbers between 100 and 199
    ${0-99}    = '[1-9]?[0-9]' # Matches 1 or 2 digit numbers between 0 and 99

    # Each Octet is one of the four possible components defined above..
    $Octet = "( ${250-255} | ${200-249} | ${100-199} | ${0-99} )"

    # IPv4 Address is 4 Octets separated by dots
    $IP4 = "($Octet\.){3}$Octet"

$IPv6Regex = @"
(?ix)       # Use extended-mode regex (white-space, comments and newlines in the regex definition are ignored)
^\s*       # Allow optional whitespace before the address

# Note: All brackets are for grouping (the resulting captures are not used)

(
        (( $Hex :){7}      ($Hex                             |:))  |       # 8 Groups of 1-4 Hex characters, or 7 Groups with elided zeroes after 7th group
        (( $Hex :){6}     (:$Hex       |               $IP4  |:))  |       # Elided zeroes after 6th Group, or 6 Groups followed by dotted IP4
        (( $Hex :){5}   (((:$Hex){1,2})|             : $IP4  |:))  |       # g:g:g:g:g::g   g:g:g:g:g::g:g   g:g:g:g:g::ip4   g:g:g:g:g::   etc
        (( $Hex :){4}   (((:$Hex){1,3})|((:$Hex)?    : $IP4 )|:))  |       # g:g:g:g::g     g:g:g:g::g:g     g:g:g:g::g:g:g   g:g:g:g::ip4   g:g:g:g::g:ip4   g:g:g:g::   etc
        (( $Hex :){3}   (((:$Hex){1,4})|((:$Hex){0,2}: $IP4 )|:))  |
        (( $Hex :){2}   (((:$Hex){1,5})|((:$Hex){0,3}: $IP4 )|:))  |
        (( $Hex :){1}   (((:$Hex){1,6})|((:$Hex){0,4}: $IP4 )|:))  |       # g::g:g:g:g:g:g g::g:g:g:g:g     ...       g::g   g::     g::g:g:g:g:ip4 ....    g::ip4   etc

    (:(((: $Hex  ){1,7})|((:$Hex){0,5}               : $IP4 )|:))          # Elided zeroes at front of address:   ::g:g:g:g:g:g:g   ::g    ::g:ip4  etc
)

# (%.+)?     # Match optional Zone Index (Scope ID) in Link Local address (there may be multiple link-local addresses (e.g. on different adapters) with different zone indexes)

\s*$       # Allow optional whitespace at the end of the address
"@

    $CompiledIPv6Regex = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList ($IPv6Regex,[System.Text.RegularExpressions.RegexOptions]::Compiled)


    # This sample is from the RegexBuddy Library

$RegexBuddy = @'
(?ix)
\A(?:                                                  # Anchor address
    (?:  # Mixed
    (?:[A-F0-9]{1,4}:){6}                                # Non-compressed
    |(?=(?:[A-F0-9]{0,4}:){2,6}                           # Compressed with 2 to 6 colons
        (?:[0-9]{1,3}\.){3}[0-9]{1,3}                     #    and 4 bytes
        \z)                                               #    and anchored
    (([0-9A-F]{1,4}:){1,5}|:)((:[0-9A-F]{1,4}){1,5}:|:)  #    and at most 1 double colon
    |::(?:[A-F0-9]{1,4}:){5}                              # Compressed with 7 colons and 5 numbers
    )
    (?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}  # 255.255.255.
    (?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])           # 255
|     # Standard
    (?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4}                    # Standard
|     # Compressed
    (?=(?:[A-F0-9]{0,4}:){0,7}[A-F0-9]{0,4}               # Compressed with at most 7 colons
    \z)                                                #    and anchored
    (([0-9A-F]{1,4}:){1,7}|:)((:[0-9A-F]{1,4}){1,7}|:)    #    and at most 1 double colon
|(?:[A-F0-9]{1,4}:){7}:|:(:[A-F0-9]{1,4}){7}           # Compressed with 8 colons
)\z                                                    # Anchor address
'@

    $CompiledRegexBuddy = New-Object -TypeName System.Text.RegularExpressions.Regex -ArgumentList ($RegexBuddy,[System.Text.RegularExpressions.RegexOptions]::Compiled)


$Php1 = @'
(?ix)
\A 
        (?: 
            # mixed 
            (?: 
                # Non-compressed 
                (?:[A-F0-9]{1,4}:){6} 
                # Compressed with at most 6 colons 
                |(?=(?:[A-F0-9]{0,4}:){0,6} 
                    (?:[0-9]{1,3}\.){3}[0-9]{1,3}    # and 4 bytes 
                    \Z)                # and anchored 
                # and at most 1 double colon 
                (([A-F0-9]{1,4}:){0,5}|:)((:[A-F0-9]{1,4}){1,5}:|:) 
            ) 
            # 255.255.255. 
            (?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3} 
            # 255 
            (?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?) 
            # Standard 
            |(?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4} 
            # Compressed with at most 7 colons 
            |(?=(?:[A-F0-9]{0,4}:){0,7}[A-F0-9]{0,4} 
                \Z) # anchored 
            # and at most 1 double colon 
            (([A-F0-9]{1,4}:){1,7}|:)((:[A-F0-9]{1,4}){1,7}|:) 
        )\Z
'@

    #endregion Script Section 1.  IPv6 Address Regexs.


    #region Script Section 2.  Test Method Script Blocks.
    # "$TestMethods" is an array of custom objects, each consisting of a test method name and a ScriptBlock that implements the test.
    # The ScriptBlock is passed a sample IPv6 address and returns True/False depending on whether the method considers the address valid.

    $TestMethods = @(

        # Test the IPv6 regex defined above

        [PsCustomObject] @{

            Name = 'IPv6 Regex'
    
            ScriptBlock =   {
                Param ([String]$TestAddress)
                Return ($TestAddress -Match $IPv6Regex)
            }
        }


    
        # Test the Compiled IPv6 regex defined above

        [PsCustomObject] @{

            Name = 'Compiled IPv6 Regex'
    
            ScriptBlock =   {
                Param ([String]$TestAddress)
                Return ($CompiledIPv6Regex.IsMatch($TestAddress))
            }
        }



        [PsCustomObject] @{

            Name = 'Php1'
    
            ScriptBlock =   {
                Param ([String]$TestAddress)
                Return ($TestAddress -Match $Php1)
            }
        }




        [PsCustomObject] @{

            Name = 'RegexBuddy'
    
            ScriptBlock =   {
                Param ([String]$TestAddress)
                Return ($TestAddress -Match $RegexBuddy)
            }
        }



        [PsCustomObject] @{

            Name = 'Compiled RegexBuddy'
    
            ScriptBlock =   {
                Param ([String]$TestAddress)
                Return ($CompiledRegexBuddy.IsMatch($TestAddress))
            }
        }



        # Tests using the [System.Net.IpAddress]::TryParse() method

        [PsCustomObject] @{
    
            Name = 'Net IpAddress TryParse() Method'
    
            ScriptBlock =   {
                Param ([String]$TestAddress)
                $IP = $Null
                Return ([System.Net.IPAddress]::TryParse($TestAddress,[Ref]$IP))
            }
        }

    
    
        [PsCustomObject] @{
    
            Name = 'Qualified Net IpAddress TryParse() Method'
    
            ScriptBlock =   {
                Param ([String]$TestAddress)
                $IP = $Null
                If ([System.Net.IPAddress]::TryParse($TestAddress,[Ref]$IP)) {
                    Return ($IP.AddressFamily -eq [System.Net.Sockets.AddressFamily]::InterNetworkV6)
                }
                else {
                    Return $False
                }
            }
        }



        # .Net example from http://home.deds.nl/~aeron/regex/
    
        [PsCustomObject] @{
    
            Name        = 'Aeron Regex'
    
            ScriptBlock =   {
                Param ([String]$TestAddress)
                $Aeron = '^(((?=.*(::))(?!.*\3.+\3))\3?|[0-9A-F]{1,4}:)([0-9A-F]{1,4}(\3|:\b)|\2){5}(([0-9A-F]{1,4}(\3|:\b|$)|\2){2}|(((2[0-4]|1[0-9]|[1-9])?[0-9]|25[0-5])\.?\b){4})\z'
                Return ($TestAddress -Match $Aeron)
            }
        }


    )
    #endregion Script Section 2.  Test Method Script Blocks.

    #region Script Section 3.  Test IPv6 Addresses.
    
    $Ipv6TestAddresses = @(

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '' }      # empty string 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::1' }      # loopback, compressed, non-routable 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::' }      # unspecified, compressed, non-routable 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:0:0:0:0:0:0:1' }      # loopback, full 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:0:0:0:0:0:0:0' }      # unspecified, full 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:DB8:0:0:8:800:200C:417A' }      # unicast, full 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'FF01:0:0:0:0:0:0:101' }      # multicast, full 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:DB8::8:800:200C:417A' }      # unicast, compressed 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'FF01::101' }      # multicast, compressed 
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '2001:DB8:0:0:8:800:200C:417A:221' }      # unicast, full 
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = 'FF01::101::2' }      # multicast, compressed 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80::217:f2ff:fe07:ed62' }      

        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0000:1234:0000:0000:C1C0:ABCD:0876' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '3ffe:0b00:0000:0000:0001:0000:0000:000a' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'FF02:0000:0000:0000:0000:0000:0000:0001' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0000:0000:0000:0000:0000:0000:0000:0001' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0000:0000:0000:0000:0000:0000:0000:0000' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '02001:0000:1234:0000:0000:C1C0:ABCD:0876' }      	# extra 0 not allowed
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '2001:0000:1234:0000:00001:C1C0:ABCD:0876' }      	# extra 0 not allowed 
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '2001:0000:1234:0000:0000:C1C0:ABCD:0876  0' }      	# junk after valid address
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '2001:0000:1234: 0000:0000:C1C0:ABCD:0876' }      	# internal space

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '3ffe:0b00:0000:0001:0000:0000:000a' }      			# seven segments
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = 'FF02:0000:0000:0000:0000:0000:0000:0000:0001' }      	# nine segments
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '3ffe:b00::1::a' }      								# double '::'
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1111:2222:3333:4444:5555:6666::' }      			# double '::'
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2::10' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'ff02::1' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2002::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:db8::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0db8:1234::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::ffff:0:0' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::1' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4:5:6:7:8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4:5:6::8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4:5::8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4::8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3::8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2::8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::2:3:4:5:6:7' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::2:3:4:5:6' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::2:3:4:5' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::2:3:4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::2:3' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::2:3:4:5:6:7:8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::2:3:4:5:6:7' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::2:3:4:5:6' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::2:3:4:5' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::2:3:4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::2:3' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4:5:6::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4:5::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4:5::7:8' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1:2:3::4:5::7:8' }      							# Double '::'
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '12345::6:7:8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4::7:8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3::7:8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2::7:8' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::7:8' }      

        # IPv4 addresses as dotted-quads
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4:5:6:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4:5::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3:4::5:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2:3::5:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1:2::5:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::5:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1::5:11.22.33.44' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:400.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:260.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:256.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:1.256.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:1.2.256.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:1.2.3.256' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:300.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:1.300.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:1.2.300.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:1.2.3.300' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:900.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:1.900.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:1.2.900.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:1.2.3.900' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:300.300.300.300' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::5:3000.30.30.30' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::400.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::260.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::256.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::1.256.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::1.2.256.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::1.2.3.256' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::300.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::1.300.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::1.2.300.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::1.2.3.300' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::900.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::1.900.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::1.2.900.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::1.2.3.900' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::300.300.300.300' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::3000.30.30.30' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::400.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::260.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::256.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.256.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.2.256.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.2.3.256' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::300.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.300.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.2.300.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.2.3.300' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::900.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.900.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.2.900.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.2.3.900' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::300.300.300.300' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::3000.30.30.30' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80::217:f2ff:254.7.237.98' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::ffff:192.168.1.26' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '2001:1:1:1:1:1:255Z255X255Y255' }      				# garbage instead of '.' in IPv4
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::ffff:192x168.1.26' }      							# ditto
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::ffff:192.168.1.1' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:0:0:0:0:0:13.1.68.3' }      # IPv4-compatible IPv6 address, full, deprecated 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:0:0:0:0:FFFF:129.144.52.38' }      # IPv4-mapped IPv6 address, full 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::13.1.68.3' }      # IPv4-compatible IPv6 address, compressed, deprecated 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::FFFF:129.144.52.38' }      # IPv4-mapped IPv6 address, compressed 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80:0:0:0:204:61ff:254.157.241.86' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80::204:61ff:254.157.241.86' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::ffff:12.34.56.78' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::ffff:2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::ffff:257.1.2.3' }      
        # [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1.2.3.4' }            # Duplicate below

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1.2.3.4:1111:2222:3333:4444::5555' }        # Aeron
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1.2.3.4:1111:2222:3333::5555' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1.2.3.4:1111:2222::5555' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1.2.3.4:1111::5555' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1.2.3.4::5555' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1.2.3.4::' }  

        # Testing IPv4 addresses represented as dotted-quads
        # Leading zero' }s in IPv4 addresses not allowed: some systems treat the leading '0' in '.086' as the start of an octal number
        # Update: The BNF in RFC-3986 explicitly defines the dec-octet (for IPv4 addresses) not to have a leading zero
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = 'fe80:0000:0000:0000:0204:61ff:254.157.241.086' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::ffff:192.0.2.128' }         # but this is OK, since there's a single digit
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = 'XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:00.00.00.00' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:000.000.000.000' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:256.256.256.256' }      

        # Not testing address with subnet mask
        # [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0DB8:0000:CD30:0000:0000:0000:0000/60' }      # full, with prefix 
        # [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0DB8::CD30:0:0:0:0/60' }      # compressed, with prefix 
        # [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0DB8:0:CD30::/60' }      # compressed, with prefix #2 
        # [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::/128' }      # compressed, unspecified address type, non-routable 
        # [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::1/128' }      # compressed, loopback address type, non-routable 
        # [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'FF00::/8' }      # compressed, multicast address type 
        # [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'FE80::/10' }      # compressed, link-local unicast, non-routable 
        # [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'FEC0::/10' }      # compressed, site-local unicast, deprecated 
        # [PsCustomObject] @{ Valid = $False; TestIPv6Address = '124.15.6.89/60' }      # standard IPv4, prefix not allowed 

        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80:0000:0000:0000:0204:61ff:fe9d:f156' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80:0:0:0:204:61ff:fe9d:f156' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80::204:61ff:fe9d:f156' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::1' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80::1' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::ffff:c000:280' }      

        # Aeron supplied these test cases
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::5555:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::5555:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::5555:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::5555:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':' }      

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::5555' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::5555' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::5555' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::5555' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::5555' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::' }      


        # Additional test cases
        # from http://rt.cpan.org/Public/Bug/Display.html?id=50693

        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0db8:85a3:0000:0000:8a2e:0370:7334' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:db8:85a3:0:0:8a2e:370:7334' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:db8:85a3::8a2e:370:7334' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0db8:0000:0000:0000:0000:1428:57ab' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0db8:0000:0000:0000::1428:57ab' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0db8:0:0:0:0:1428:57ab' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0db8:0:0::1428:57ab' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0db8::1428:57ab' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:db8::1428:57ab' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0000:0000:0000:0000:0000:0000:0000:0001' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::1' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::ffff:0c22:384e' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0db8:1234:0000:0000:0000:0000:0000' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:0db8:1234:ffff:ffff:ffff:ffff:ffff' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '2001:db8:a::123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'fe80::' }      

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '123' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = 'ldkfj' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '2001::FFD3::57ab' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '2001:db8:85a3::8a2e:37023:7334' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '2001:db8:85a3::8a2e:370k:7334' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1:2:3:4:5:6:7:8:9' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1::2::3' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1:::3:4:5' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1:2:3::4:5:6:7:8:9' }      

        # From Aeron 
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555:6666::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555:6666::8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555::8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555::7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::2222:3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555:6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555::123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::5555:6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::5555:6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::5555:6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::5555:6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::4444:5555:6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::4444:5555:6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::4444:5555:6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::3333:4444:5555:6666:123.123.123.123' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::2222:3333:4444:5555:6666:123.123.123.123' }      

        # Combinations of '0' and '::'
        # NB: these are all sytactically correct, but are bad form 
        #   because '0' adjacent to '::' should be combined into '::'
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::0:0:0:0:0:0:0' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::0:0:0:0:0:0' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::0:0:0:0:0' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::0:0:0:0' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::0:0:0' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::0:0' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::0' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:0:0:0:0:0:0::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:0:0:0:0:0::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:0:0:0:0::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:0:0:0::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:0:0::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:0::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0::' }      

        # New invalid from Aeron
        # Invalid data
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = 'XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX' }      

        # Too many components
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:8888:9999' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:8888::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555:6666:7777:8888:9999' }      

        # Too few components
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111' }      

        # Missing :
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '11112222:3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:22223333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:33334444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:44445555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:55556666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:66667777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:77778888' }      

        # Missing : intended for ::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':2222:3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666:7777:8888' }      

        # :::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::2222:3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:::3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:::4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:::' }      

        # Double ::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222::4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555:7777::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555:7777:8888::' }      

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444:5555::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444:5555:6666::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444:5555:6666:7777::' }      

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444:5555::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444:5555:6666::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444:5555:6666:7777::' }      

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555:6666::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555:6666:7777::' }      

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::6666::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::6666:7777::' }      

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555::7777::' }      


        # Too many components' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:8888:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555:6666:7777:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:1.2.3.4.5' }      

        # Too few components
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1.2.3.4' }      

        # Missing :
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '11112222:3333:4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:22223333:4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:33334444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:44445555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:55556666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:66661.2.3.4' }      

        # Missing .
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:255255.255.255' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:255.255255.255' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:255.255.255255' }      

        # Missing : intended for ::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':3333:4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':2222:3333:4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666:1.2.3.4' }      

        # :::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::2222:3333:4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:::3333:4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:::4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:::5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:::6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:::1.2.3.4' }      

        # Double ::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222::4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333::5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444::6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555::1.2.3.4' }      

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333::5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444::6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444:5555::1.2.3.4' }      

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444::6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444:5555::1.2.3.4' }      

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555::1.2.3.4' }      

        # Missing parts
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::.' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::..' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::...' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1...' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.2..' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.2.3.' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::.2..' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::.2.3.' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::..3.' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::..3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::...4' }      

        # Extra : in front
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666:7777::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::2222:3333:4444:5555:6666:7777:8888' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::3333:4444:5555:6666:1.2.3.4' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::2222:3333:4444:5555:6666:1.2.3.4' }      

        # Extra : at end
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666::8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555::8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555::7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555:6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::5555:6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::5555:6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::5555:6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444:5555:6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::4444:5555:6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::4444:5555:6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444:5555:6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::3333:4444:5555:6666:7777:8888:' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555:6666:7777:8888:' }      

        # Additional cases: http://crisp.tweakblogs.net/blog/2031/ipv6-validation-%28and-caveats%29.html
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '0:a:b:c:d:e:f::' }      
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::0:a:b:c:d:e:f' }       # syntactically correct, but bad form (::0:... could be combined)
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = 'a:b:c:d:e:f:0::' }      
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':10.0.0.1' }      

        # Further test cases...

        ## From: http://home.deds.nl/~aeron/regex/valid_ipv6.txt

        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777::' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555:6666::' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555::' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555:6666::8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555::8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555::7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::2222:3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555:6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444:5555::123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333:4444::6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222:3333::5555:6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::5555:6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::5555:6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::5555:6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111:2222::4444:5555:6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::4444:5555:6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::4444:5555:6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '1111::3333:4444:5555:6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::3333:4444:5555:6666:123.123.123.123' }
        [PsCustomObject] @{ Valid = $True;  TestIPv6Address = '::2222:3333:4444:5555:6666:123.123.123.123' }


        ## From: http://home.deds.nl/~aeron/regex/invalid_ipv6.txt

        # Invalid data
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = 'XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:XXXX' }

        # To many components
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:8888:9999' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:8888::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555:6666:7777:8888:9999' }

        # To few components
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111' }

        # Missing :
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '11112222:3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:22223333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:33334444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:44445555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:55556666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:66667777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:77778888' }

        # Missing : intended for ::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':2222:3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666:7777:8888' }

        # :::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::2222:3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:::3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:::4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:::' }

        # Double ::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222::4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555:7777::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555:7777:8888::' }
    
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444:5555::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444:5555:6666::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444:5555:6666:7777::' }
    
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444:5555::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444:5555:6666::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444:5555:6666:7777::' }
    
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555:6666::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555:6666:7777::' }
    
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::6666::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::6666:7777::' }
    
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555::7777::' }
    
        # Invalid data
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = 'XXXX:XXXX:XXXX:XXXX:XXXX:XXXX:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:00.00.00.00' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:000.000.000.000' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:256.256.256.256' }
    
        # To few components
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:8888:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666::1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555:6666:7777:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:1.2.3.4.5' }
    
        # To few components
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1.2.3.4' }

        # Missing :
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '11112222:3333:4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:22223333:4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:33334444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:44445555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:55556666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:66661.2.3.4' }

        # Missing .
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:255255.255.255' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:255.255255.255' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:255.255.255255' }

        # Missing : intended for ::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':3333:4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':2222:3333:4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666:1.2.3.4' }

        # :::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::2222:3333:4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:::3333:4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:::4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:::5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:::6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:::1.2.3.4' }

        # Double ::
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222::4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333::5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444::6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555::1.2.3.4' }

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333::5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444::6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444:5555::1.2.3.4' }

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444::6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444:5555::1.2.3.4' }

        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555::1.2.3.4' }

        # Missing parts
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::.' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::..' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::...' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1...' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.2..' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::1.2.3.' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::.2..' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::.2.3.' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::..3.' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::..3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::...4' }

        # Extra : in front
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666:7777::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::2222:3333:4444:5555:6666:7777:8888' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444:5555::1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333:4444::6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222:3333::5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111:2222::4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':1111::3333:4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::3333:4444:5555:6666:1.2.3.4' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::2222:3333:4444:5555:6666:1.2.3.4' }

        # Extra : at end
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:7777:::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666:::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = ':::' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555:6666::8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555::8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444:5555::7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333:4444::6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222:3333::5555:6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::5555:6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::5555:6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::5555:6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111:2222::4444:5555:6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::4444:5555:6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::4444:5555:6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '1111::3333:4444:5555:6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::3333:4444:5555:6666:7777:8888:' }
        [PsCustomObject] @{ Valid = $False; TestIPv6Address = '::2222:3333:4444:5555:6666:7777:8888:' }

    )
    #endregion Script Section 3.  Test IPv6 Addresses.

    #region Script Section 4.  Main Code.


    # Run each of the test methods against the list of test addresses

    $UniqueTests = $IPv6TestAddresses | Sort-Object -Property TestIPv6Address -Unique
    $TestResults = @()    # We have to gather the result objects manually rather than just emitting them to the pipeline because Measure-Command will discard them otherwise

    Foreach ($Test in ($TestMethods | Where-Object Name -Match $TestName)) {

        $TestFailedCount = 0

        $Elapsed = Measure-Command {

            Foreach ($TestAddress in $UniqueTests) {

                $TestResult = & $Test.ScriptBlock $TestAddress.TestIPv6Address

                $Passed = ($TestAddress.Valid -Eq $TestResult)
                If (-Not $Passed) {$TestFailedCount++}

                $TestResults += [PsCustomObject] @{
                    PsTypeName     = 'RegexMatchResult'
                    TestName       = $Test.Name
                    TestAddress    = $TestAddress.TestIPv6Address
                    ExpectedResult = $TestAddress.Valid
                    ActualResult   = $TestResult
                    Pass           = $Passed
                }
            }
        }

        Write-Verbose ("{0,2} of {1} unique tests failed in {2,4:F0}ms for '{3}'" -f $TestFailedCount, $UniqueTests.Count, $Elapsed.TotalMilliseconds, $Test.Name)

    }

    # Todo: leave the filtering and formatting out of the script... (but just interested in failures for now)

    # Format the output unless requested not to...

    If ($NoFormat) {
        $TestResults      # Just output the result objects
    }
    Else {
        # Format the collected test result objects; show only failing tests...
        $TestResults | Where-Object {-not $_.Pass} | Format-Table TestName, TestAddress, ExpectedResult, ActualResult -AutoSize
    }

    #endregion Script Section 4.  Main Code.
}  # End Function Ipv6Regex



<#

Additional Notes.


This script is inspired by a Perl script from here: http://download.dartware.com/thirdparty/test-ipv6-regex.pl
However, some of the regexs are new or significantly refactored. A large number of the test address cases are
taken from this site of from others sites linked from this page.

Overview:

The regex matches the following IPv6 address forms. Note that these are all the same address: 

fe80:0000:0000:0000:0204:61ff:fe9d:f156       -- full form of IPv6 
fe80:0:0:0:204:61ff:fe9d:f156                 -- drop leading zeroes 
fe80::204:61ff:fe9d:f156                      -- collapse multiple zeroes to :: in the IPv6 address 
fe80:0000:0000:0000:0204:61ff:254.157.241.86  -- IPv4 dotted quad at the end 
fe80:0:0:0:0204:61ff:254.157.241.86           -- drop leading zeroes, IPv4 dotted quad at the end 
fe80::204:61ff:254.157.241.86                 -- dotted quad at the end, multiple zeroes collapsed 

In addition, the regular expression matches these IPv6 forms: 

::1        -- localhost 
fe80::     -- link-local prefix 
2001::     -- global unicast prefix 

Link Local addresses may have a Scope-ID (or Zone Index) at the end of the address following a percent sign.
The Scope Id will be the adapter index (in Windows).  The Scope ID is used to distinguish between multiple 
similar link local addresses on different interfaces.  http://msdn.microsoft.com/en-us/library/aa921042.aspx
The regex here can test for Scope IDs, but this is currently commented out of the regex (see code below)

See http://www.ietf.org/rfc/rfc4291.txt "IP Version 6 Addressing Architecture"
Section 2.2 "Text Representation of Addresses"
(An extract of this section of the RFC is included at the end of this script)
...and http://tools.ietf.org/html/rfc5952 (Updates rfc4291)

Also see: http://www.ietf.org/rfc/rfc3986.txt "Uniform Resource Identifier (URI): Generic Syntax"
Section 3.2.2 Syntax Components - Host
(An extract of this section of the RFC is included at the end of this script)

And: http://tools.ietf.org/html/rfc4007 "IPv6 Scoped Address Architecture"
     http://en.wikipedia.org/wiki/IPv6_address

Todo: Add -StrictIPv4 switch (for leading 0 in IPv4 Octet)


#------------------------------------------------------------------------------

Further Background:

There are a number of RFCs covering IPv6 formats.  Some relevent extracts are included here:


From http://www.ietf.org/rfc/rfc4291.txt "IP Version 6 Addressing Architecture"

2.2.  Text Representation of Addresses

There are three conventional forms for representing IPv6 addresses as
text strings:

1. The preferred form is x:x:x:x:x:x:x:x, where the 'x's are one to
    four hexadecimal digits of the eight 16-bit pieces of the address.
    Examples:

        ABCD:EF01:2345:6789:ABCD:EF01:2345:6789

        2001:DB8:0:0:8:800:200C:417A

    Note that it is not necessary to write the leading zeros in an
    individual field, but there must be at least one numeral in every
    field (except for the case described in 2.).

2. Due to some methods of allocating certain styles of IPv6
    addresses, it will be common for addresses to contain long strings
    of zero bits.  In order to make writing addresses containing zero
    bits easier, a special syntax is available to compress the zeros.
    The use of "::" indicates one or more groups of 16 bits of zeros.
    The "::" can only appear once in an address.  The "::" can also be
    used to compress leading or trailing zeros in an address.

    For example, the following addresses

        2001:DB8:0:0:8:800:200C:417A   a unicast address
        FF01:0:0:0:0:0:0:101           a multicast address
        0:0:0:0:0:0:0:1                the loopback address
        0:0:0:0:0:0:0:0                the unspecified address

    may be represented as

        2001:DB8::8:800:200C:417A      a unicast address
        FF01::101                      a multicast address
        ::1                            the loopback address
        ::                             the unspecified address

3. An alternative form that is sometimes more convenient when dealing
    with a mixed environment of IPv4 and IPv6 nodes is
    x:x:x:x:x:x:d.d.d.d, where the 'x's are the hexadecimal values of
    the six high-order 16-bit pieces of the address, and the 'd's are
    the decimal values of the four low-order 8-bit pieces of the
    address (standard IPv4 representation).  Examples:

        0:0:0:0:0:0:13.1.68.3

        0:0:0:0:0:FFFF:129.144.52.38

    or in compressed form:

        ::13.1.68.3

        ::FFFF:129.144.52.38



2.3.  Text Representation of Address Prefixes

The text representation of IPv6 address prefixes is similar to the
way IPv4 address prefixes are written in Classless Inter-Domain
Routing (CIDR) notation [CIDR].  An IPv6 address prefix is
represented by the notation:

    ipv6-address/prefix-length

where

    ipv6-address    is an IPv6 address in any of the notations listed
                    in Section 2.2.

    prefix-length   is a decimal value specifying how many of the
                    leftmost contiguous bits of the address comprise
                    the prefix.

For example, the following are legal representations of the 60-bit
prefix 20010DB80000CD3 (hexadecimal):

    2001:0DB8:0000:CD30:0000:0000:0000:0000/60
    2001:0DB8::CD30:0:0:0:0/60
    2001:0DB8:0:CD30::/60

The following are NOT legal representations of the above prefix:

    2001:0DB8:0:CD3/60   may drop leading zeros, but not trailing
                        zeros, within any 16-bit chunk of the address

    2001:0DB8::CD30/60   address to left of "/" expands to
                        2001:0DB8:0000:0000:0000:0000:0000:CD30

    2001:0DB8::CD3/60    address to left of "/" expands to
                        2001:0DB8:0000:0000:0000:0000:0000:0CD3

When writing both a node address and a prefix of that node address
(e.g., the node's subnet prefix), the two can be combined as follows:

    the node address      2001:0DB8:0:CD30:123:4567:89AB:CDEF
    and its subnet number 2001:0DB8:0:CD30::/60

    can be abbreviated as 2001:0DB8:0:CD30:123:4567:89AB:CDEF/60


#------------------------------------------------------------------------------

From: http://www.ietf.org/rfc/rfc3986.txt "Uniform Resource Identifier (URI): Generic Syntax"
Section 3.2.2 Syntax Components - Host


A 128-bit IPv6 address is divided into eight 16-bit pieces.  Each
piece is represented numerically in case-insensitive hexadecimal,
using one to four hexadecimal digits (leading zeroes are permitted).
The eight encoded pieces are given most-significant first, separated
by colon characters.  Optionally, the least-significant two pieces
may instead be represented in IPv4 address textual format.  A
sequence of one or more consecutive zero-valued 16-bit pieces within
the address may be elided, omitting all their digits and leaving
exactly two consecutive colons in their place to mark the elision.

    IPv6address =                            6( h16 ":" ) ls32
                /                       "::" 5( h16 ":" ) ls32
                / [               h16 ] "::" 4( h16 ":" ) ls32
                / [ *1( h16 ":" ) h16 ] "::" 3( h16 ":" ) ls32
                / [ *2( h16 ":" ) h16 ] "::" 2( h16 ":" ) ls32
                / [ *3( h16 ":" ) h16 ] "::"    h16 ":"   ls32
                / [ *4( h16 ":" ) h16 ] "::"              ls32
                / [ *5( h16 ":" ) h16 ] "::"              h16
                / [ *6( h16 ":" ) h16 ] "::"

    ls32        = ( h16 ":" h16 ) / IPv4address
                ; least-significant 32 bits of address

    h16         = 1*4HEXDIG
                ; 16 bits of address represented in hexadecimal

A host identified by an IPv4 literal address is represented in
dotted-decimal notation (a sequence of four decimal numbers in the
range 0 to 255, separated by "."), as described in [RFC1123] by
reference to [RFC0952].  Note that other forms of dotted notation may
be interpreted on some platforms, as described in Section 7.4, but
only the dotted-decimal form of four octets is allowed by this
grammar.

    IPv4address = dec-octet "." dec-octet "." dec-octet "." dec-octet

    dec-octet   = DIGIT                 ; 0-9
                / %x31-39 DIGIT         ; 10-99
                / "1" 2DIGIT            ; 100-199
                / "2" %x30-34 DIGIT     ; 200-249
                / "25" %x30-35          ; 250-255


#------------------------------------------------------------------------------


Additional ad-hoc References:

https://gist.github.com/cpetschnig/294476     -- Ruby IPv6 validator
http://people.spodhuis.org/phil.pennock/software/emit_ipv6_regexp-0.304   -- Uses syntax from rfc3986
http://download.dartware.com/thirdparty/test-ipv6-regex.pl  -- Perl Script
http://crisp.tweakblogs.net/blog/2031/ipv6-validation-%28and-caveats%29.html   -- PHP and Test cases
http://crisp.tweakblogs.net/blog/3049/ipv6-validation-more-caveats.html   -- PHP and Test cases
http://home.deds.nl/~aeron/regex/    -- shortest regexs - various flavours
http://home.deds.nl/~aeron/regex/valid_ipv6.txt      -- Valid IPv6 addresses test cases
http://home.deds.nl/~aeron/regex/invalid_ipv6.txt      -- Invalid IPv6 addresses test cases
http://msdn.microsoft.com/en-us/library/aa915659.aspx  -- IPv6
http://msdn.microsoft.com/en-us/library/aa917150.aspx  -- IPv6 Addressing
http://msdn.microsoft.com/en-us/library/aa921042.aspx  -- IPv6 Addresses
http://msdn.microsoft.com/en-us/library/windows/desktop/aa385325(v=vs.85).aspx     -- Zone index



Many examples from: http://download.dartware.com/thirdparty/test-ipv6-regex.pl
Main reference http://www.rfc-editor.org/rfc/rfc3986.txt


Other Regexs....

Three samples from http://download.dartware.com/thirdparty/test-ipv6-regex.pl

$aeron = qr/^(((?=(?>.*?::)(?!.*::)))(::)?([0-9A-F]{1,4}::?){0,5}|([0-9A-F]{1,4}:){6})(\2([0-9A-F]{1,4}(::?|$)){0,2}|((25[0-5]|(2[0-4]|1[0-9]|[1-9])?[0-9])(\.|$)){4}|[0-9A-F]{1,4}:[0-9A-F]{1,4})(?<![^:]:)(?<!\.)\z/i;


$dartware = qr/^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*$/;

~~~~~~~~~~~~~~~~~~~~

Ruby example from https://gist.github.com/cpetschnig/294476

IPV6_REGEX = /^\s*((([0-9A-Fa-f]{1,4}:){7}([0-9A-Fa-f]{1,4}|:))|(([0-9A-Fa-f]{1,4}:){6}(:[0-9A-Fa-f]{1,4}|((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){5}(((:[0-9A-Fa-f]{1,4}){1,2})|:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3})|:))|(([0-9A-Fa-f]{1,4}:){4}(((:[0-9A-Fa-f]{1,4}){1,3})|((:[0-9A-Fa-f]{1,4})?:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){3}(((:[0-9A-Fa-f]{1,4}){1,4})|((:[0-9A-Fa-f]{1,4}){0,2}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){2}(((:[0-9A-Fa-f]{1,4}){1,5})|((:[0-9A-Fa-f]{1,4}){0,3}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(([0-9A-Fa-f]{1,4}:){1}(((:[0-9A-Fa-f]{1,4}){1,6})|((:[0-9A-Fa-f]{1,4}){0,4}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:))|(:(((:[0-9A-Fa-f]{1,4}){1,7})|((:[0-9A-Fa-f]{1,4}){0,5}:((25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)(\.(25[0-5]|2[0-4]\d|1\d\d|[1-9]?\d)){3}))|:)))(%.+)?\s*$/

~~~~~~~~~~~~~~~~~~~~

Perl example based on rfc from: http://people.spodhuis.org/phil.pennock/software/emit_ipv6_regexp-0.304
# Phil Pennock who submitted a RE generated automatically from the full grammar in RFC3986 
#	http://people.spodhuis.org/phil.pennock/software/emit_ipv6_regexp-0.304
$philpennock = qr/^(?:(?:(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):){6})(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):(?:(?:[0-9a-fA-F]{1,4})))|(?:(?:(?:(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9])))))))|(?:(?:::(?:(?:(?:[0-9a-fA-F]{1,4})):){5})(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):(?:(?:[0-9a-fA-F]{1,4})))|(?:(?:(?:(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9])))))))|(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})))?::(?:(?:(?:[0-9a-fA-F]{1,4})):){4})(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):(?:(?:[0-9a-fA-F]{1,4})))|(?:(?:(?:(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9])))))))|(?:(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):){0,1}(?:(?:[0-9a-fA-F]{1,4})))?::(?:(?:(?:[0-9a-fA-F]{1,4})):){3})(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):(?:(?:[0-9a-fA-F]{1,4})))|(?:(?:(?:(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9])))))))|(?:(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):){0,2}(?:(?:[0-9a-fA-F]{1,4})))?::(?:(?:(?:[0-9a-fA-F]{1,4})):){2})(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):(?:(?:[0-9a-fA-F]{1,4})))|(?:(?:(?:(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9])))))))|(?:(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):){0,3}(?:(?:[0-9a-fA-F]{1,4})))?::(?:(?:[0-9a-fA-F]{1,4})):)(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):(?:(?:[0-9a-fA-F]{1,4})))|(?:(?:(?:(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9])))))))|(?:(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):){0,4}(?:(?:[0-9a-fA-F]{1,4})))?::)(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):(?:(?:[0-9a-fA-F]{1,4})))|(?:(?:(?:(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9]))\.){3}(?:(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9])))))))|(?:(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):){0,5}(?:(?:[0-9a-fA-F]{1,4})))?::)(?:(?:[0-9a-fA-F]{1,4})))|(?:(?:(?:(?:(?:(?:[0-9a-fA-F]{1,4})):){0,6}(?:(?:[0-9a-fA-F]{1,4})))?::))))$/;

# RFC 3986 states:
#       IPv6address =                            6( h16 ":" ) ls32
#                   /                       "::" 5( h16 ":" ) ls32
#                   / [               h16 ] "::" 4( h16 ":" ) ls32
#                   / [ *1( h16 ":" ) h16 ] "::" 3( h16 ":" ) ls32
#                   / [ *2( h16 ":" ) h16 ] "::" 2( h16 ":" ) ls32
#                   / [ *3( h16 ":" ) h16 ] "::"    h16 ":"   ls32
#                   / [ *4( h16 ":" ) h16 ] "::"              ls32
#                   / [ *5( h16 ":" ) h16 ] "::"              h16
#                   / [ *6( h16 ":" ) h16 ] "::"
# 
#       ls32        = ( h16 ":" h16 ) / IPv4address
#                   ; least-significant 32 bits of address
# 
#       h16         = 1*4HEXDIG


my $IPV4_OCTET = qr/(?:25[0-5]|(?:[1-9]|1[0-9]|2[0-4])?[0-9])/;
my $IPV4_REGEXP = qr/(?:(?:${IPV4_OCTET}\.){3}${IPV4_OCTET})/o;
my $IPV6_H16 = qr/(?:[0-9a-fA-F]{1,4})/;
my $IPV6_LS32 = qr/(?:(?:${IPV6_H16}:${IPV6_H16})|${IPV4_REGEXP})/o;
my $IPV6_REGEXP = qr/(?:
  (?:(?:                                             (?:${IPV6_H16}:){6} )${IPV6_LS32}) |
  (?:(?:                                          :: (?:${IPV6_H16}:){5} )${IPV6_LS32}) |
  (?:(?: (?:                       ${IPV6_H16} )? :: (?:${IPV6_H16}:){4} )${IPV6_LS32}) |
  (?:(?: (?: (?:${IPV6_H16}:){0,1} ${IPV6_H16} )? :: (?:${IPV6_H16}:){3} )${IPV6_LS32}) |
  (?:(?: (?: (?:${IPV6_H16}:){0,2} ${IPV6_H16} )? :: (?:${IPV6_H16}:){2} )${IPV6_LS32}) |
  (?:(?: (?: (?:${IPV6_H16}:){0,3} ${IPV6_H16} )? ::    ${IPV6_H16}:     )${IPV6_LS32}) |
  (?:(?: (?: (?:${IPV6_H16}:){0,4} ${IPV6_H16} )? ::                     )${IPV6_LS32}) |
  (?:(?: (?: (?:${IPV6_H16}:){0,5} ${IPV6_H16} )? ::                     )${IPV6_H16} ) |
  (?:(?: (?: (?:${IPV6_H16}:){0,6} ${IPV6_H16} )? ::                     )            )
  )/ox;



~~~~~~~~~~~~~~~~~~~~~~~~~~

PHP Regex by "WCP" in comment on http://crisp.tweakblogs.net/blog/2031/ipv6-validation-%28and-caveats%29.html


$dec_octet = "([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])";
 $ipv4address = "($dec_octet\.){3}$dec_octet";
 $h16 = "[0-9a-fA-F]{1,4}";
 $ls32 = "($h16:$h16|$ipv4address)";
 $ipv6address = "(" .
 "(" .
 "($h16:){6}" .
 "|" .
 "::($h16:){5}" .
 "|" .
 "($h16)?::($h16:){4}" .
 "|" .
 "(($h16:){0,1}$h16)?::($h16:){3}" .
 "|" .
 "(($h16:){0,2}$h16)?::($h16:){2}" .
 "|" .
 "(($h16:){0,3}$h16)?::$h16:" .
 "|" .
 "(($h16:){0,4}$h16)?::" .
 ")" .
 "$ls32" .
 "|" .
 "(" .
 "(($h16:){0,5}$h16)?::$h16" .
 "|" .
 "(($h16:){0,6}$h16)?::" .
 ")" .
 ")";

~~~~~~~~~~~~~~~~~~~~~~~~~~

PHP Function/Regex from http://crisp.tweakblogs.net/blog/3049/ipv6-validation-more-caveats.html


function validateIPv4($IP) 
{ 
    return $IP == long2ip(ip2long($IP)); 
} 

function validateIPv6($IP) 
{ 
    if (strlen($IP) < 3) 
        return $IP == '::'; 

    if (strpos($IP, '.')) 
    { 
        $lastcolon = strrpos($IP, ':'); 
        if (!($lastcolon && validateIPv4(substr($IP, $lastcolon + 1)))) 
            return false; 

        $IP = substr($IP, 0, $lastcolon) . ':0:0'; 
    } 

    if (strpos($IP, '::') === false) 
    { 
        return preg_match('/\A(?:[a-f0-9]{1,4}:){7}[a-f0-9]{1,4}\z/i', $IP); 
    } 

    $colonCount = substr_count($IP, ':'); 
    if ($colonCount < 8) 
    { 
        return preg_match('/\A(?::|(?:[a-f0-9]{1,4}:)+):(?:(?:[a-f0-9]{1,4}:)*[a-f0-9]{1,4})?\z/i', $IP); 
    } 

    // special case with ending or starting double colon 
    if ($colonCount == 8) 
    { 
        return preg_match('/\A(?:::)?(?:[a-f0-9]{1,4}:){6}[a-f0-9]{1,4}(?:::)?\z/i', $IP); 
    } 

    return false; 
} 



~~~~~~~~~~~~~~~~~~~~~~~~~~
 
PHP regex from the Regular Expression Cookbook chapter 7.17 'Matching IPv6 Addresses' on page 387. 
by Jan Goyvaerts and Steven Levithan 

function validateIPv6($IP) 
{ 
    return preg_match('/\A 
        (?: 
            # mixed 
            (?: 
                # Non-compressed 
                (?:[A-F0-9]{1,4}:){6} 
                # Compressed with at most 6 colons 
                |(?=(?:[A-F0-9]{0,4}:){0,6} 
                    (?:[0-9]{1,3}\.){3}[0-9]{1,3}    # and 4 bytes 
                    \Z)                # and anchored 
                # and at most 1 double colon 
                (([A-F0-9]{1,4}:){0,5}|:)((:[A-F0-9]{1,4}){1,5}:|:) 
            ) 
            # 255.255.255. 
            (?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3} 
            # 255 
            (?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?) 
            # Standard 
            |(?:[A-F0-9]{1,4}:){7}[A-F0-9]{1,4} 
            # Compressed with at most 7 colons 
            |(?=(?:[A-F0-9]{0,4}:){0,7}[A-F0-9]{0,4} 
                \Z) # anchored 
            # and at most 1 double colon 
            (([A-F0-9]{1,4}:){1,7}|:)((:[A-F0-9]{1,4}){1,7}|:) 
        )\Z/ix', 
        $IP 
    ); 
} 



#>
