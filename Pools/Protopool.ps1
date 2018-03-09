﻿param(
    [Parameter(Mandatory = $true)]
    [String]$Querymode = $null,
    [Parameter(Mandatory = $false)]
    [pscustomobject]$Info
)

#. .\..\Include.ps1

$Name = (Get-Item $script:MyInvocation.MyCommand.Path).BaseName
$ActiveOnManualMode = $true
$ActiveOnAutomaticMode = $true
$ActiveOnAutomatic24hMode = $false
$AbbName = 'PRO'
$WalletMode = 'WALLET'
$ApiUrl = 'https://protopool.net/api'
$MineUrl = 'eu1.protopool.net'
$Location = 'EU'
$RewardType = "PPS"
$UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/60.0.3112.101 Safari/537.36'
$Result = @()


if ($Querymode -eq "info") {
    $Result = [PSCustomObject]@{
        Disclaimer               = "No registration, No autoexchange, need wallet for each coin on config.txt"
        ActiveOnManualMode       = $ActiveOnManualMode
        ActiveOnAutomaticMode    = $ActiveOnAutomaticMode
        ActiveOnAutomatic24hMode = $ActiveOnAutomatic24hMode
        ApiData                  = $True
        AbbName                  = $AbbName
        WalletMode               = $WalletMode
        RewardType               = $RewardType
    }
}


if ($Querymode -eq "speed") {
    try {
        $http = $ApiUrl + "/walletEx?address=" + $Info.user
        $Request = Invoke-WebRequest -UserAgent $UserAgent $http -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
    } catch {}

    $Result = @()

    if (![string]::IsNullOrEmpty($Request)) {
        $Request.Miners |ForEach-Object {
            $Result += [PSCustomObject]@{
                PoolName   = $name
                Version    = $_.version
                Algorithm  = get_algo_unified_name $_.Algo
                Workername = (($_.password -split 'ID=')[1] -split ',')[0]
                Diff       = $_.difficulty
                Rejected   = $_.rejected
                Hashrate   = $_.accepted
            }
        }
        Remove-Variable Request
    }
}


if ($Querymode -eq "wallet") {
    try {
        $http = $ApiUrl + "/wallet?address=" + $Info.user
        $Request = Invoke-WebRequest $http -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
    } catch {}

    if (![string]::IsNullOrEmpty($Request)) {
        $Result = [PSCustomObject]@{
            Pool     = $name
            currency = $Request.currency
            balance  = $Request.balance
        }
        Remove-Variable Request
    }
    Start-Sleep -Seconds 1 # Prevent API Saturation
}


if (($Querymode -eq "core" ) -or ($Querymode -eq "Menu")) {
    try {
        $Request = Invoke-WebRequest $($ApiUrl + "/status") -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
        $RequestCurrencies = Invoke-WebRequest $($ApiUrl + "/currencies") -UserAgent $UserAgent -UseBasicParsing -timeoutsec 5 | ConvertFrom-Json
    } catch {
        Write-Host $Name 'API NOT RESPONDING...ABORTING'
        Exit
    }

    $RequestCurrencies | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name | Where-Object {
        $RequestCurrencies.$_.'24h_blocks' -gt 0 -and
        $RequestCurrencies.$_.hashrate -gt 0 -and
        $RequestCurrencies.$_.workers -gt 0
    } | ForEach-Object {


        $Coin = $RequestCurrencies.$_
        $Pool_Algo = get_algo_unified_name $Coin.algo
        $Pool_Coin = get_coin_unified_name $Coin.name
        $Pool_Symbol = $_

        $Divisor = 1000000

        switch ($Pool_Algo) {
            "blake2s" {$Divisor *= 1000}
            "blakecoin" {$Divisor *= 1000}
            "equihash" {$Divisor /= 1000}
            "scrypt" {$Divisor *= 1000}
            "sha256" {$Divisor *= 1000}
        }

        # Comment the coins if you use 6-8 GPUs
        switch ($Pool_symbol) {
            'ARGO' { $Port = 4932 }
            'BHD' { $Port = 3572 }
            'BWK' { $Port = 3832 }
            'CBS' { $Port = 4231 }
            'CURV' { $Port = 4912 }
            'LIZ' { $Port = 4922 }
            'RACE' { $Port = 4532 }
            'SPD' { $Port = 3582 }
            'TIN' { $Port = 8532 }
            Default { $Port = $Coin.Port}
        }

        $Result += [PSCustomObject]@{
            Algorithm             = $Pool_Algo
            Info                  = $Pool_Coin
            Price                 = $Coin.estimate / $Divisor
            Price24h              = $Coin.'24h_btc' / $Divisor
            Protocol              = "stratum+tcp"
            Host                  = $MineUrl
            Port                  = $Port
            User                  = $CoinsWallets.get_item($Pool_Symbol)
            Pass                  = "c=$Pool_Symbol,ID=#WorkerName#"
            Location              = $Location
            SSL                   = $false
            Symbol                = $Pool_Symbol
            AbbName               = $AbbName
            ActiveOnManualMode    = $ActiveOnManualMode
            ActiveOnAutomaticMode = $ActiveOnAutomaticMode
            PoolWorkers           = $Coin.workers
            PoolHashRate          = $Coin.hashrate
            WalletMode            = $WalletMode
            Walletsymbol          = $Pool_Symbol
            PoolName              = $Name
            Fee                   = $Request.($Coin.algo).fees / 100
            RewardType            = $RewardType
        }
    }
    Remove-Variable Request
    Remove-Variable RequestCurrencies
}


$Result | ConvertTo-Json | Set-Content $info.SharedFile
Remove-Variable Result
