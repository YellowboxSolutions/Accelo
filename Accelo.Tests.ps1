$here = Split-Path -Path $MyInvocation.MyCommand.Path

Import-Module -force $here\Accelo.psm1
Import-module Pester

$testuser = "testuser"
$testpass = ConvertTo-SecureString -string "testpass" -AsPlainText -Force
$testcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $testuser,$testpass
$testtoken = "testtokencontent"
$testscope = "read(all)"
$testBaseUri = "https://example.com"
$testAuthUri = "https://test1.api.accelo.com/oauth/v0"

Describe "Get-AcceloUri" {
    Context "Get API URI" {
        It "It returns valid api uri" {
            $UriSplat = @{
                Uri = "https://example.com"
                Path = "endpoint/test"
                Limit = 2
                Filters = "standing(closed)"
                Fields = "Name,Title"
                Search = "Test Search"
            }
            $uri = Get-AcceloUri @UriSplat

            $uri | Should -BeOfType System.Uri
            $uri.Host | Should -Be "example.com"
            $uri.AbsolutePath | Should -Be "/endpoint/test"
            $uri.Query | Should -BeLike "*_limit=2*"
            $uri.Query | Should -BeLike "*_filters=standing(closed)*"
            $uri.Query | Should -BeLike "*_fields=Name%2cTitle*"
            $uri.Query | Should -BeLike "*_search=Test+Search*"
        }
    }
}

Describe "Invoke-Accelo" {
    BeforeAll{
        Mock Invoke-WebRequest -modulename Accelo -Verifiable{
            $content = @{
                method = [string]$method
                headers = [hashtable]$headers
                uri = [uri]$uri
            }
            $content = $content|ConvertTo-Json
            write-verbose "Mock response content: $content"
            $request = @{
                content = $content
            }
            $request
        }
    }
    
    Context "Invoke Methods" {
        [uri]$TestUri = "https://example.com/anything"
        $methods = @(
            @{ method = "GET"}
            @{ method = "POST"}
            @{ method = "GET"}
            @{ method = "DELETE"}
        )

        It "Raises error when no auth." {
            {Invoke-Accelo -uri $TestUri} | Should -Throw "No Auth info provided"
        }

        It "Uses method <method> correctly." -testcases $methods {
            param($method)
            $headers = @{Authorization = "TestKey"}
            Invoke-Accelo -headers $headers -uri "https://example.com/anything" -method $method|
            select-object -ExpandProperty method|
            Should -be $method
        }
    }

    Context "Invoke with queries as part of uri" {
        $headers = @{Authorization = "TestKey"}
        $queries = @{
            testq1 = "testval1"
            testq2 = "testval2"
        }

        It "Queries the correct endpoint" {
            $uri = Invoke-Accelo -header $headers -uri "$testuri/anything" |
            Select-Object -ExpandProperty uri
            $uri | Should -be "$testuri/anything"
        }
    }

    Context "Invoke with headers" {
        $headers = @{
            Authorization = "testtoken"
            testq1 = "testval1"
            testq2 = "testval2"
        }

        It "Sends header strings from parameters" {
            $response = Invoke-Accelo -uri "$testuri/get" -headers $headers
            foreach ($key in $headers.Keys) {
                $response.headers.$key  | Should -Be $headers.$key
            }
        }
    }
}

Describe "Connect-Accelo" {
    BeforeAll{
        Mock Invoke-WebRequest -modulename Accelo {
            $content = @{
            }
            $content = $content|ConvertTo-Json
            write-verbose "Mock response content: $content"
            $request = @{
                content = $content
            }
            $request
        }
        Mock Invoke-WebRequest -modulename Accelo -ParameterFilter {$uri -like "*oauth2*"} {
            $response = @{
                access_token = 'testtoken'
                method = [string]$method
                headers = [hashtable]$headers
                uri = [uri]$uri
                body = [hashtable]$body
            }
            $response = @{Content = ($response|convertto-json)}
            $response
        }

        $connectSplat = @{
            User = $testuser
            Secret = $testpass
            BaseUri = $testBaseUri
            Scope = $testscope
        }

        $response = Connect-Accelo @connectSplat
        $response
    }
    
    Context "Connect with Username and Password" {
        It "Sends proper grant_type" {
            Assert-MockCalled Invoke-WebRequest -ModuleName Accelo -Scope Describe -ParameterFilter {($uri -like "*oauth2*") -and ($body["grant_type"] -eq "client_credentials")}
        }

        It "Returns a proper AcceloSession" {
            $response.BaseUri | Should -be "$testBaseUri/"
            $response.User | Should -be $testuser
            $response.Secret | Should -be $testpass
            $response.AccessToken | Should -be 'testtoken'
            $response.ElapsedTime.IsRunning|Should -BeTrue
        }

    }
}

Describe "Get-AcceloCompany" {
    BeforeAll{
        Mock Invoke-WebRequest -modulename Accelo -ParameterFilter {$uri -like "*oauth2*"} {
            $response = @{access_token = 'testtoken'}
            $response = @{Content = ($response|convertto-json)}
            $response
        }

        Connect-Accelo -BaseUri "$testBaseUri/auth" -user $testuser -Secret $testpass
    }

    Context "Get all companies" {
        Mock Invoke-WebRequest -ModuleName Accelo -ParameterFilter {$uri -like "*companies*"} {
            $companies = @(
                1..10 | ForEach-Object {
                    @{ Id = $_; Name = "Name of $_"}
                }
            )
            $response = @{Content = (@{response = $companies} | ConvertTo-Json)}
            $response
        }

        $companies = Get-AcceloCompany

        It "Invokes WebRequest" {
            Assert-MockCalled Invoke-WebRequest -ModuleName Accelo -times 1
        }
    }

    Context "Get company by Id" {
        Mock Invoke-WebRequest -ModuleName Accelo -ParameterFilter {$uri -like "*companies/9876"} {
            $company = @{Id = 9876; Name = "Company 9876"}
            $response = @{Content = (@{response = $company} | ConvertTo-Json)}
            $response
        }
        $company = Get-AcceloCompany -Id 9876

        It "Invokes WebRequest" {
            Assert-MockCalled Invoke-WebRequest -ModuleName Accelo -ParameterFilter {$uri -like "*companies/9876*"}
            $company.id | Should -BeLike "*9876*"
        }
    }
    
}

Describe "Get-AcceloRequest" {
    BeforeAll{
        Mock Invoke-WebRequest -modulename Accelo -ParameterFilter {$uri -like "*oauth2*"} {
            $response = @{access_token = 'testtoken'}
            $response = @{Content = ($response|convertto-json)}
            $response
        }

        Connect-Accelo -BaseUri "$testBaseUri/auth" -user $testuser -Secret $testpass
    }

    Context "Get all requests" {
        Mock Invoke-WebRequest -ModuleName Accelo -ParameterFilter {$uri -like "*requests*"} {
            $requests = @(
                1..10 | ForEach-Object {
                    @{ Id = $_; Name = "Name of $_"}
                }
            )
            $response = @{Content = (@{response = $requests} | ConvertTo-Json)}
            $response
        }

        $requests = Get-AcceloRequest

        It "Invokes WebRequest" {
            Assert-MockCalled Invoke-WebRequest -ModuleName Accelo -ParameterFilter {$uri -like "*requests*"} -times 1
        }
    }

    Context "Get request by Id" {
        Mock Invoke-WebRequest -ModuleName Accelo -ParameterFilter {$uri -like "*requests/9876"} {
            $request = @{Id = 9876; Name = "Request 9876"}
            $response = @{Content = (@{response = $request} | ConvertTo-Json)}
            $response
        }
        $request = Get-AcceloRequest -Id 9876

        It "Invokes WebRequest" {
            Assert-MockCalled Invoke-WebRequest -ModuleName Accelo -ParameterFilter {$uri -like "*requests/9876"}
            $request.id | Should -BeLike "*9876*"
        }
    }
}

Describe "Add-AcceloRequest" {
    BeforeEach {
        Mock Invoke-WebRequest -modulename Accelo -Verifiable {
            $request = @{
                content = (@{ response = $body}|Convertto-json)
            }
            $request
        }
        
    }
    $token = "testtoken"

    Context "Add a new request" {
        $testRequestSplat = @{
            typeId = "4"
            title = "Test Title"    
            affiliationId = "88"
            body = "Test body"
        }
        It "Should return a valid request" {
            Add-AcceloRequest -uri $testuri -token $token @testRequestSplat|
            Select-Object -ExpandProperty title|
            should -be "$($testRequestSplat.title)"
        }
    }
}

Describe "Get-AcceloAffiliations"{
    Context "Get unfiltered list of affiliations" {
        It "Returns list of affiliations." {
            $true
        }
    }
}