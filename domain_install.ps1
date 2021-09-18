Install-WindowsFeature AD-Domain-Services -IncludeManagementTools
$pass = ConvertTo-SecureString -String P@ssw0rd2admin -AsPlainText -Force 
Install-ADDSForest -DomainName "lab.local" -DomainNetBiosName "LAB" -InstallDns:$true -NoRebootOnCompletion:$true -SafeModeAdministratorPassword $pass -Force 
shutdown -r
