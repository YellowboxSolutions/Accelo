$here = Split-Path -Path $MyInvocation.MyCommand.Path

Get-Module Accelo | Remove-Module -Force
Import-Module $here\Accelo.psm1
Import-module Pester

$testuser = "testuser"
$testpass = ConvertTo-SecureString -string "testpass" -AsPlainText -Force
$testcred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $testuser,$testpass
$testuri = "https://example.com/sdf"
$testtoken = "testtokencontent"

Describe "Invoke-Accelo" {
    BeforeEach{
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
        $methods = @(
            @{ method = "GET"}
            @{ method = "POST"}
            @{ method = "GET"}
            @{ method = "DELETE"}
        )

        It "Uses method <method> correctly." -testcases $methods {
            param($method)
            Invoke-Accelo -uri "$testuri/anything" -method $method|
            select-object -ExpandProperty method|
            Should -be $method
        }
    }

    Context "Invoke with queries as part of uri" {
        $queries = @{
            testq1 = "testval1"
            testq2 = "testval2"
        }

        It "Uri contains query string <query> sent as parameters" {
            $uri = Invoke-Accelo -uri "$testuri/anything" -query $queries|
            Select-Object -ExpandProperty uri
            $uri | Should -belike "*testq1=testval1*"
            $uri | Should -belike "*testq2=testval2*"
        }
    }
    Context "Invoke with headers" {
        $headers = @{
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

Describe "Get-AcceloToken" {
    Context "Get Token" {
        Mock -ModuleName Accelo -ParameterFilter {$method -eq "POST"} Invoke-Accelo {
            return @{access_token = "$($headers.Authorization)"}
        }
        $token = Get-AcceloToken -uri $testuri -credential $testcred -scope "TestScope2"

        It "Returns a token built from authinfo header" {
            $token | Should -BeLike "Basic *"
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
            # affiliation = "88"
            # affiliation_company_name = "Yellowbox Solutions"
            # affiliation_company_phone = "2562739272"
            # affiliation_contact_firstname = "Ken"
            # affiliation_contact_surname = "Mitchell"
            # affiliation_email = "dummy@ken-mitchell.com"
            # affiliation_phone = "2562739272"
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