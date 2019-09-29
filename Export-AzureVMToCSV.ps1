param(
    [string]$subscriptionId="",
    [string]$file="Azure-VMs.csv",
    [string]$tenantID=""
) 

if ($subscriptionId -eq "") 
{
    Write-Host "Subscription Id is missing."
    $subscriptionId = Read-Host -Prompt "Please provide the Azure subscription ID:"    
} 
else 
{
    Write-Host "Subscription Id selected is: "  $subscriptionId
}

if ($tenantID -eq "") 
{
    Write-Host "Azure AD Tenant Id is missing."
    $tenantID = Read-Host -Prompt "Please provide the Azure Ad Tenant ID:"    
} 
else 
{
    Write-Host "Azure Ad Tenant Id selected is: "  $tenantID
}


#Write-host "Disconnecting already cached accounts."
#Disconnect-AzAccount

#prompt for login to Azure account
Write-Host "Login to Azure account who has the access to read Azure VM information".
#Connect-AzAccount -Tenant $tenantID

#get the subscription details
$sub = Get-AzSubscription -SubscriptionId $subscriptionId -ErrorAction Continue
Select-AzSubscription -SubscriptionId $subscriptionId -ErrorAction Continue

#declare VM object variable
$vmobjects = @()

Write-Host Retrieving Azure VMs from subscription $sub.SubscriptionName

#retrive all VMs in subscription
$vms = Get-AzVM -Status
try
    {
        foreach ($vm in $vms)
        {
            #retrive the Network configuration of VM
            $nics = $vm.NetworkProfile.NetworkInterfaces
            $nicTemp = Get-AzNetworkInterface -ResourceId $nics[0].Id
            $privateIP = $nicTemp.IpConfigurations[0].PrivateIpAddress
            

            #get public IP address and its name
            $publicIPId = $nicTemp.IpConfigurations[0].PublicIpAddress.Id
            if($publicIPId -eq $null)
            {
                $publicIP = "No PublicIP"
            }
            else
            {
                $publicIP = $publicIPId.Substring($publicIPId.LastIndexOf("/")+1)                
            }            
            $publicIPAddress = Get-AzPublicIpAddress -Name $publicIP
            

            #get NSG name attached to primary NIC
            $nsgId = $nicTemp.NetworkSecurityGroup.Id          
            if($nsgId -eq $null)
            {
                $nsgName = "No NSG"
            }
            else
            {
                $nsgName = $nsgId.Substring($nsgId.LastIndexOf("/")+1)                
            }
            


            
            $subnetId = $nicTemp.IpConfigurations[0].Subnet.Id            
            $subnet = Get-AzVirtualNetworkSubnetConfig -ResourceId $subnetId
            
            #retrive VNET name to which Azure VM belongs
            $tempString = $subnetId.Substring($subnetId.IndexOf("virtualNetworks"))
            $t = $tempString.Remove($tempString.IndexOf("/subnets"))
            $vnetName = $t.Substring($t.IndexOf("/") + 1)
            
            $vmInfo = 
                @{
                    'Subscription Name'                 = $sub.Name                
                    'VM Name'                           = $vm.Name                    
                    'Resource Group Name'               = $vm.ResourceGroupName
                    'Location'                          = $vm.Location
                    'VMSize'                            = $vm.HardwareProfile.VMSize
                    'Status'                            = $vm.PowerState
                    'Availability Set'                  = $vm.AvailabilitySetReference.Id 
                    'Private IP'                        = $privateIP
                    'Public IP Name'                    = $publicIP
                    'Public IP Address'                 = $publicIPAddress.IpAddress
                    'OS Type'                           = $vm.StorageProfile.OsDisk.OsType
                    'primary NIC Name'                  = $nicTemp.Name
                    'NSG Name'                          = $nsgName
                    "Subnet"                            = $subnet.Name
                    "VNET Name"                         = $vnetName                    
                
                 }

            $vmobjects += New-Object PSObject -Property $vmInfo
        }  
    }
    catch
    {
        Write-Host $error[0]
    }


$vmobjects | Export-Csv -NoTypeInformation -Path $file
Write-Host "VM list written to $file"


