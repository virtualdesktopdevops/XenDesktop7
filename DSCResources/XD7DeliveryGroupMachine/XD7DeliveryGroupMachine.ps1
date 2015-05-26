﻿Import-LocalizedData -BindingVariable localizedData -FileName Resources.psd1;

function Get-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Name,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String[]] $Members,
        [Parameter()] [AllowNull()] [System.Management.Automation.PSCredential] $Credential,
        [Parameter()] [ValidateSet('Present','Absent')] [System.String] $Ensure = 'Present'
    )
    begin {
        if (-not (TestXDModule -Name 'Citrix.Broker.Admin.V2' -IsSnapin)) {
            ThrowInvalidProgramException -ErrorId 'Citrix.Broker.Admin.V2' -ErrorMessage $localizedData.XenDesktopSDKNotFoundError;
        }
    }
    process {
        $scriptBlock = {
            Add-PSSnapin -Name 'Citrix.Broker.Admin.V2';
            $targetResource = @{
                Name = $using:Name;
                Members = @();
                Ensure = 'Absent';
            }
            $targetResource['Members'] = Get-BrokerMachine -DesktopGroupName $using:Name | Select -Expand DnsName;
            if ($targetResource['Members']) { $targetResource['Ensure'] = 'Present'; }
            return $targetResource;
        }
        
        $invokeCommandParams = @{
            ScriptBlock = $scriptBlock;
            ErrorAction = 'Stop';
        }
        if ($Credential) { AddInvokeScriptBlockCredentials -Hashtable $invokeCommandParams -Credential $Credential; }
        else { $invokeCommandParams['ScriptBlock'] = [System.Management.Automation.ScriptBlock]::Create($scriptBlock.ToString().Replace('$using:','$')); }
        Write-Verbose ($localizedData.InvokingScriptBlockWithParams -f [System.String]::Join("','", @($Name, $Members, $Ensure)));
        $targetResource = Invoke-Command  @invokeCommandParams;
        return $targetResource;
    }
} #end function Get-TargetResource

function Test-TargetResource {
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Name,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String[]] $Members,
        [Parameter()] [AllowNull()] [System.Management.Automation.PSCredential] $Credential,
        [Parameter()] [ValidateSet('Present','Absent')] [System.String] $Ensure = 'Present'
    )
    process {
        $VerbosePreference = 'SilentlyContinue';
        Import-Module "$env:ProgramFiles\WindowsPowerShell\Modules\cCitrixXenDesktop7\DSCResources\XD7Common\XD7Common.psd1";
        $VerbosePreference = 'Continue';
        
        $targetResource = Get-TargetResource @PSBoundParameters;
        if (TestXDMachineMembership -RequiredMembers $Members -ExistingMembers $targetResource.Members -Ensure $Ensure) {
            Write-Verbose ($localizedData.ResourceInDesiredState -f $Name);
            return $true;
        }
        else {
            Write-Verbose ($localizedData.ResourceNotInDesiredState -f $Name);
            return $false;
        }
    } #end process
} #end function Get-TargetResource

function Set-TargetResource {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String] $Name,
        [Parameter(Mandatory)] [ValidateNotNullOrEmpty()] [System.String[]] $Members,
        [Parameter()] [AllowNull()] [System.Management.Automation.PSCredential] $Credential,
        [Parameter()] [ValidateSet('Present','Absent')] [System.String] $Ensure = 'Present'
    )
    begin {
        if (-not (TestXDModule -Name 'Citrix.Broker.Admin.V2' -IsSnapin)) {
            ThrowInvalidProgramException -ErrorId 'Citrix.Broker.Admin.V2' -ErrorMessage $localizedData.XenDesktopSDKNotFoundError;
        }
    }
    process {
        $scriptBlock = {
            $VerbosePreference = 'SilentlyContinue';
            Add-PSSnapin -Name 'Citrix.Broker.Admin.V2';
            Import-Module "$env:ProgramFiles\WindowsPowerShell\Modules\cCitrixXenDesktop7\DSCResources\XD7Common\XD7Common.psd1";
            $VerbosePreference = 'Continue';

            $brokerMachines = Get-BrokerMachine -DesktopGroupName $using:Name;
            foreach ($member in $using:Members) {
                $brokerMachine = ResolveXDBrokerMachine -MachineName $member -BrokerMachines $brokerMachines;
                if (($using:Ensure -eq 'Absent') -and ($brokerMachine.DesktopGroupName -eq $using:Name)) {
                    Write-Verbose ($using:localizedData.RemovingDeliveryGroupMachine -f $member, $using:Name);
                    $brokerMachine | Remove-BrokerMachine -DesktopGroup $using:Name -Force;
                }
                elseif (($using:Ensure -eq 'Present') -and ($brokerMachine.DesktopGroupName -ne $using:Name)) {
                    Write-Verbose ($using:localizedData.AddingDeliveryGroupMachine -f $member, $using:Name);
                    $brokerMachine = GetXDBrokerMachine -MachineName $member;
                    if ($brokerMachine -eq $null) {
                        ThrowInvalidOperationException -ErrorId 'MachineNotFound' -Message ($using:localizedData.MachineNotFoundError -f $member);
                    }
                    else {
                        $brokerMachine | Add-BrokerMachine -DesktopGroup $using:Name;
                    }
                }
            } #end foreach member
        } #end scriptBlock

        $invokeCommandParams = @{
            ScriptBlock = $scriptBlock;
            ErrorAction = 'Stop';
        }
        if ($Credential) { AddInvokeScriptBlockCredentials -Hashtable $invokeCommandParams -Credential $Credential; }
        else { $invokeCommandParams['ScriptBlock'] = [System.Management.Automation.ScriptBlock]::Create($scriptBlock.ToString().Replace('$using:','$')); }
        Write-Verbose ($localizedData.InvokingScriptBlockWithParams -f [System.String]::Join("','", @($Name, $Members, $Ensure)));
        Invoke-Command  @invokeCommandParams;
    } #end process
} #end function Set-TargetResource
