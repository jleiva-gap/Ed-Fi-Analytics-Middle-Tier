# SPDX-License-Identifier: Apache-2.0
# Licensed to the Ed-Fi Alliance under one or more agreements.
# The Ed-Fi Alliance licenses this file to you under the Apache License, Version 2.0.
# See the LICENSE and NOTICES files in the project root for more information.

<#
    .SYNOPSIS
        Automation script for running build operations from the command line.

    .DESCRIPTION
        Provides automation of the following tasks:
        
        * Build: runs `dotnet build` with several implicit steps
          (clean, restore, inject version information).

        * Publish: creates the publish files.

        * CreateZip: adds published files to a Zip file.
        
        * UnitTest: runs the unit tests.

        * IntegrationTest: runs the Integration tests.

    .EXAMPLE
        .\build.ps1 build -Configuration Release -Version "2.0.0" -BuildCounter 45

        Overrides the default build configuration (Debug) to build in release
        mode with assembly version 2.0.0.45.
	
    .EXAMPLE
        .\build.ps1 CreateZip
        The files published in zip archives.
        
	 .EXAMPLE
        .\build.ps1 unittest
        Output: test results displayed in the console and saved to XML files.
		
	 .EXAMPLE
        .\build.ps1 integrationtest
        Output: test results displayed in the console and saved to XML files.
#>
[CmdLetBinding()]

param(
    # Command to execute, defaults to "Build".
    [string]
    [ValidateSet("Clean", "Build", "Publish", "CreateZip", "UnitTest", "IntegrationTest")]
    $Command = "Build",

    [switch] $SelfContained,

    # Assembly and package version number, defaults 2.6.1
    [string]
    $Version = "2.6.1",

    # Build counter from the automation tool.
    [string]
    $BuildCounter = "1",

    # .NET project build configuration, defaults to "Debug". Options are: Debug, Release.
    [string]
    [ValidateSet("Debug", "Release")]
    $Configuration = "Debug"
)

$Env:MSBUILDDISABLENODEREUSE = "1"

#$solution = "Application\Ed-Fi-ODS-Tools.sln"
$solutionRoot = "$PSScriptRoot/src"
$maintainers = "Ed-Fi Alliance, LLC and contributors"
Import-Module -Name ("$PSScriptRoot/eng/build-helpers.psm1") -Force
$publishOutputPath = "$solutionRoot/../publish"
$publishFddDirectoryName = "EdFi.AnalyticsMiddleTier"
$publishScdDirectoryName = "EdFi.AnalyticsMiddleTier-win10.x64"
$publishFddOutputDirectory = "$publishOutputPath/$publishFddDirectoryName"
$publishScdOutputDirectory = "$publishOutputPath/$publishScdDirectoryName"
$publishFddZipFile = "$publishFddDirectoryName.zip"
$publishScdZipFile = "$publishScdDirectoryName.zip"
$testProjectName = "EdFi.AnalyticsMiddleTier.Tests"

function Clean {
    Invoke-Execute { dotnet clean $solutionRoot -c $Configuration --nologo -v minimal }
}

function CleanPublishFddOutputDirectory {
    if (Test-Path -Path $publishFddOutputDirectory) {
        Remove-Item -Recurse ("$publishFddOutputDirectory/*.*")
    }
    if (Test-Path -Path ("$publishOutputPath/$publishFddZipFile")) {
        Remove-Item -Recurse ("$publishOutputPath/$publishFddZipFile")
    }
}

function CleanPublishScdOutputDirectory {
    if (Test-Path -Path $publishScdOutputDirectory) {
        Remove-Item -Recurse ("$publishScdOutputDirectory/*.*")
    }
    if (Test-Path -Path ("$publishOutputPath/$publishScdZipFile")) {
        Remove-Item -Recurse ("$publishOutputPath/$publishScdZipFile")
    }
}

function AssemblyInfo {
    Invoke-Execute {
        $assembly_version = "$Version.$BuildCounter"

        Invoke-RegenerateFile ("$solutionRoot/Directory.Build.props") @"
<Project>
    <!-- This file is generated by the build script. -->
    <PropertyGroup>
        <Product>Ed-Fi AMT</Product>
        <Authors>$maintainers</Authors>
        <Company>$maintainers</Company>
        <Copyright>Copyright © 2016 Ed-Fi Alliance</Copyright>
        <VersionPrefix>$assembly_version</VersionPrefix>
        <VersionSuffix></VersionSuffix>
    </PropertyGroup>
</Project>

"@
    }
}

function Compile {
    Invoke-Execute {
        dotnet --info
        dotnet build $solutionRoot -c $Configuration --nologo
Write-Host "TEST!!!"
        # Copy .env file if it exists
        #if (Test-Path -Path $solutionRoot/$testProjectName/.env -PathType leaf) {
        #    $doc = New-Object System.Xml.XmlDocument
        #    $projectFile = Get-Item $solutionRoot/$testProjectName/$testProjectName'.csproj'
        #    $doc.Load($projectFile)
        #    $TargetFrameworkNode = $doc.SelectSingleNode("Project//PropertyGroup//TargetFramework")

        #    if ($TargetFrameworkNode) {
        #        $TargetFramework = $TargetFrameworkNode.InnerText
        #        Copy-Item $solutionRoot/$testProjectName/.env -Destination $solutionRoot/$testProjectName/bin/$Configuration/$TargetFramework/ -Force
        #    }
        #}
    }
}

function Publish {
    Invoke-Execute {
        $project = "$solutionRoot/EdFi.AnalyticsMiddleTier.Console"
		if ($SelfContained) {
            CleanPublishScdOutputDirectory
            Write-Host "Self contained." -ForegroundColor Cyan
            dotnet publish $project -c $Configuration /p:EnvironmentName=Production -o "$publishScdOutputDirectory" --self-contained -r win10-x64 --no-build --nologo
        }
        else 
        {
            CleanPublishFddOutputDirectory
            Write-Host "Not self contained." -ForegroundColor Cyan
            dotnet publish $project -c $Configuration /p:EnvironmentName=Production -o "$publishFddOutputDirectory" --no-self-contained --no-build --nologo
        }
    }
}

function CreateZip {
    Invoke-Execute {
        $fddPackDestination = ("$publishOutputPath/$publishFddZipFile")
        $scdPackDestination = ("$publishOutputPath/$publishScdZipFile")
        if(Test-Path $publishFddOutputDirectory){
            if (Test-Path $fddPackDestination) {
                Remove-Item $fddPackDestination
            }
            Compress-Archive -Path $publishFddOutputDirectory -DestinationPath $fddPackDestination
        }
        if(Test-Path $publishScdOutputDirectory){
            if (Test-Path $scdPackDestination) {
                Remove-Item $scdPackDestination
            }
            Compress-Archive -Path $publishScdOutputDirectory -DestinationPath $scdPackDestination
        }
    }
}

function RunTests {
    param (
        # File search filter
        [string]
        $Filter,
		[string]
        $Category
    )

    $testAssemblyPath = "$solutionRoot/$Filter/bin/$Configuration"
    $testAssemblies = Get-ChildItem -Path $testAssemblyPath -Filter "$Filter.dll" -Recurse

    if ($testAssemblies.Length -eq 0) {
        Write-Host "no test assemblies found in $testAssemblyPath"
    }

    $testAssemblies | ForEach-Object {
        Write-Host "Executing: dotnet test $($_)"
        Invoke-Execute { dotnet test --filter Category=$Category $_ }
    }
}

function UnitTests {
    Invoke-Execute { RunTests -Filter $testProjectName -Category UnitTest}
}

function IntegrationTests {
    Invoke-Execute { RunTests -Filter $testProjectName -Category IntegrationTest}
}

function Invoke-Build {
    Write-Host "Building Version $Version" -ForegroundColor Cyan
    Invoke-Step { Clean }
    Invoke-Step { AssemblyInfo }
    Invoke-Step { Compile }
}

function Invoke-Publish {
    Invoke-Build
    Invoke-Step { Publish }
}

function Invoke-Clean {
    Invoke-Step { Clean }
}

function Invoke-PublishClean {
    Invoke-Step { CleanPublishFddOutputDirectory }
    Invoke-Step { CleanPublishScdOutputDirectory }
}

function Invoke-UnitTests {
    Invoke-Step { UnitTests }
}

function Invoke-IntegrationTests {
    Invoke-Step { IntegrationTests }
}

function Invoke-CreateZip {
    Invoke-Step { CreateZip }
}

Invoke-Main {
    switch ($Command) {
        Clean { 
            Invoke-Clean
            Invoke-PublishClean
        }
        Build { Invoke-Build }
        UnitTest { Invoke-UnitTests }
		IntegrationTest { Invoke-IntegrationTests }
        Publish { Invoke-Publish }
        CreateZip { Invoke-CreateZip }
        default { throw "Command '$Command' is not recognized" }
    }
}