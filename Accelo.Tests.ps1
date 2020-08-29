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
                uri = [string]$uri
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
        Mock Invoke-WebRequest -modulename Accelo -Verifiable{
            $content = @{
                method = [string]$method
                headers = [hashtable]$headers
                uri = [string]$uri
            }
            $content = $content|ConvertTo-Json
            write-verbose "Mock response content: $content"
            $request = @{
                content = $content
            }
            $request
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
        It "Returns expected content from body" {
            $response.BaseUri |
            Should -be "$testBaseUri/"
        }

        It "Sets the session user" {
            $response.User | Should -be $testuser
        }

        It "Sets the session secret" {
            $response.Secret | Should -be $testpass
        }

        It "Starts a Stopwatch" {
            $response.ElapsedTime.IsRunning|Should -BeTrue
        }
    }
}

Describe "Get-AcceloCompanies" {
    Context "Get unfiltered list of companies" {
        It "Returns list of companies." {
            $true
        }
    }
}

Describe "Get-AcceloRequests" {
    BeforeEach {
        Mock Invoke-WebRequest -modulename Accelo -Verifiable {
            $returnObject = @(
                @{id = "1"; title = "title 1"}
                @{id = "2"; title = "title 2"}
            )
            $request = @{
                content = (@{ response = $returnObject}|Convertto-json)
            }
            $request
        }
        
    }
    Context "Get unfiltered list of requests" {
        It "Returns list of requests." {
            $listOfRequests = Get-AcceloRequests -uri $testuri -token $testtoken
            $listOfRequests | Should -HaveCount 2
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