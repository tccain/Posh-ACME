. $PSScriptRoot\..\Posh-ACME\DnsPlugins\Azure.ps1
. $PSScriptRoot\..\Posh-ACME\Private\MockWrappers.ps1

Describe "Connect-AZTenant" {

    $fakeTokenResponse = [pscustomobject]@{
        expires_on   = '1530691200' # 2018-07-04 08:00:00 UTC
        access_token = 'faketoken'
    }

    $script:UseBasic = @{}

    Mock -CommandName Invoke-RestMethod -MockWith { return $fakeTokenResponse }
    Mock -CommandName ConvertFrom-AccessToken -MockWith { return $fakeTokenResponse }
    Mock -CommandName Get-DateTimeOffsetNow -MockWith {
        return [DateTimeOffset]::Parse('2018-07-04T09:00:00Z')
    }

    $fakeGoodToken = [pscustomobject]@{
        Expires    = [DateTimeOffset]::Parse('2018-07-04T09:05:00Z') # just after mocked "Now"
        AuthHeader = @{ Authorization = 'Bearer fakegoodtoken' }
    }

    $fakeExpiredToken = [pscustomobject]@{
        Expires    = [DateTimeOffset]::Parse('2018-07-04T08:55:00Z') # just before mocked "Now"
        AuthHeader = @{ Authorization = 'Bearer fakeexpiredtoken' }
    }

    Context "Credential param set" {

        $fakeTenant = '00000000-0000-0000-0000-000000000000'
        $fakePass = "fake+p&ss" | ConvertTo-SecureString -AsPlainText -Force
        $fakeCred = New-Object System.Management.Automation.PSCredential('fake user', $fakePass)

        It "calls Invoke-RestMethod if no existing token" {
            $script:AZToken = $null
            Connect-AZTenant -AZTenantId $fakeTenant -AZAppCred $fakeCred
            Assert-MockCalled -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It -ParameterFilter {
                $Body -match "[&?]client_id=fake%20user(&|$)" -and $Body -match "[&?]client_secret=fake%2[Bb]p%26ss(&|$)"
            }
            Assert-MockCalled -CommandName ConvertFrom-AccessToken -Times 0 -Exactly -Scope It
        }
        It "calls Invoke-RestMethod if token expired" {
            $script:AZToken = $fakeExpiredToken
            Connect-AZTenant -AZTenantId $fakeTenant -AZAppCred $fakeCred
            Assert-MockCalled -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It
            Assert-MockCalled -CommandName ConvertFrom-AccessToken -Times 0 -Exactly -Scope It
        }
        It "sets new AZToken if token expired" {
            $script:AZToken | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader.Authorization | Should -BeExactly 'Bearer faketoken'
            $script:AZToken.Expires | Should -Be ([DateTimeOffset]::Parse('2018-07-04T07:55:00Z'))
        }
        It "calls nothing if current token is valid" {
            $script:AZToken = $fakeGoodToken
            Connect-AZTenant -AZTenantId $fakeTenant -AZAppCred $fakeCred
            Assert-MockCalled -CommandName Invoke-RestMethod -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName ConvertFrom-AccessToken -Times 0 -Exactly -Scope It
        }
        It "does not overwrite existing token if current token is valid" {
            $script:AZToken | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader.Authorization | Should -BeExactly $fakeGoodToken.AuthHeader.Authorization
            $script:AZToken.Expires | Should -Be $fakeGoodToken.Expires
        }

    }

    Context "Token param set" {

        $fakeAccessToken = 'blah.blah.blah'

        It "calls ConvertFrom-AccessToken if no existing token" {
            $script:AZToken = $null
            Connect-AZTenant -AZAccessToken $fakeAccessToken
            Assert-MockCalled -CommandName Invoke-RestMethod -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName ConvertFrom-AccessToken -Times 1 -Exactly -Scope It
        }
        It "calls ConvertFrom-AccessToken if token expired" {
            $script:AZToken = $fakeExpiredToken
            Connect-AZTenant -AZAccessToken $fakeAccessToken
            Assert-MockCalled -CommandName Invoke-RestMethod -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName ConvertFrom-AccessToken -Times 1 -Exactly -Scope It
        }
        It "uses passed in token if AZToken expired" {
            $script:AZToken | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader.Authorization | Should -BeExactly 'Bearer faketoken'
            $script:AZToken.Expires | Should -Be ([DateTimeOffset]::Parse('2018-07-04T07:55:00Z'))
        }
        It "calls nothing if current token is valid" {
            $script:AZToken = $fakeGoodToken
            Connect-AZTenant -AZAccessToken $fakeAccessToken
            Assert-MockCalled -CommandName Invoke-RestMethod -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName ConvertFrom-AccessToken -Times 0 -Exactly -Scope It
        }
        It "does not overwrite existing token if current token is valid" {
            $script:AZToken | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader.Authorization | Should -BeExactly $fakeGoodToken.AuthHeader.Authorization
            $script:AZToken.Expires | Should -Be $fakeGoodToken.Expires
        }

    }

    Context "IMDS param set" {

        It "calls Invoke-RestMethod if no existing token" {
            $script:AZToken = $null
            Connect-AZTenant -AZUseIMDS
            Assert-MockCalled -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It
            Assert-MockCalled -CommandName ConvertFrom-AccessToken -Times 0 -Exactly -Scope It
        }
        It "calls Invoke-RestMethod if token expired" {
            $script:AZToken = $fakeExpiredToken
            Connect-AZTenant -AZUseIMDS
            Assert-MockCalled -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It
            Assert-MockCalled -CommandName ConvertFrom-AccessToken -Times 0 -Exactly -Scope It
        }
        It "sets new AZToken if token expired" {
            $script:AZToken | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader.Authorization | Should -BeExactly 'Bearer faketoken'
            $script:AZToken.Expires | Should -Be ([DateTimeOffset]::Parse('2018-07-04T07:55:00Z'))
        }
        It "calls nothing if current token is valid" {
            $script:AZToken = $fakeGoodToken
            Connect-AZTenant -AZUseIMDS
            Assert-MockCalled -CommandName Invoke-RestMethod -Times 0 -Exactly -Scope It
            Assert-MockCalled -CommandName ConvertFrom-AccessToken -Times 0 -Exactly -Scope It
        }
        It "does not overwrite existing token if current token is valid" {
            $script:AZToken | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader | Should -Not -BeNullOrEmpty
            $script:AZToken.AuthHeader.Authorization | Should -BeExactly $fakeGoodToken.AuthHeader.Authorization
            $script:AZToken.Expires | Should -Be $fakeGoodToken.Expires
        }

    }

}
