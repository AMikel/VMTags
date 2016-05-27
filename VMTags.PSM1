<#
.Synopsis
   Function looks for the Tags field in VMs and returns an object with the tags for each VM
.DESCRIPTION
   Function requires a VM object to be inputed into the $VMs parameter. Get-VM cmdlet will return a VM object.
   The function can process multiple VMs.
.EXAMPLE
   Get-VMTags (get-vm)
.EXAMPLE
   Get-VMTags (get-vm "Jenkins")
#>
function Get-VMTags
{
    [CmdletBinding()]
    [OutputType([psobject[]])]
    Param
    (
        # This is a VM object or a collection of VM objects
        #Accepts multiple objects and from the pipeline as well
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [Microsoft.HyperV.PowerShell.VirtualMachineBase[]]$VMS
    
    )

    Begin{}
    Process{
        
        foreach($vm in $VMS){
            #Returns Null if no tags are found         
            if((check-vmtags($vm)) -eq $false){
                return $null
            }
    
            #looks for "Tags:" string in notes field. Splits and tokenizes it
            #returns an array of the tags
            $notes = $vm.Notes
            $split = $notes -split "`n"
            [string]$rawstring = $split | Select-String -SimpleMatch -Pattern "Tags:"
            $rawtags = $rawstring.IndexOf("Tags:")+5 | foreach {$rawstring.Substring("$_")}
            $tokens = $rawtags -split ";"
            $tags = $tokens | foreach {$($_).trim(" ")} | foreach { $_} 

            $table = @{}
            $table.VMName = $vm.Name
            $table.Tags = $Tags

            $Object = New-Object -TypeName psobject -Property $table
            
            Write-Output $object
        }#Process end
    }
    End{}
}#get-vmtags end

<#
.Synopsis
   Test to see if a tag is present on a virtual machine. Returns true if it does, false if not.
.DESCRIPTION
   Funtion will take in a virtual machine object and will return true or false on whether the tag is present. The tag is a string type. Return type is boolean
.EXAMPLE
   Test-vmtag (Get-VM "Jenkins") -Filter "IIS"
.EXAMPLE
   Test-vmtag (Get-VM "Jenkins") -Filter "AutoTag"
#>
function Test-VMTag
{
    [CmdletBinding()]
    [OutputType([boolean])]
    Param
    (
        #VM object. The output of Get-VM will work. 
        [Parameter(
                   Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [Microsoft.HyperV.PowerShell.VirtualMachineBase]$VM,
        
        #String variable.
        [Parameter(Mandatory=$true)]
        $Filter
        
    )

    Begin{}
    Process{

        write-verbose "Checking tags for $(($VM).name)"        
        $tags = (Get-VMTags -vm  $VM).tags
        
        #returns false if no tags are present
        if($tags -eq $null){
            write-verbose "No tags found for $(($VM).name)"
            Write-Output $false
        }else{
        
            #loops through the tags and returns true if match is made
            $returntag = $false 
            $tags | foreach { if ($_ -eq $filter) {
                                write-verbose "Tag found on $(($VM).name) for $filter"
                                $returntag = $true
                                
                                } 
                            }
            if ($returntag -eq $false) { Write-Verbose "No tag found on $(($VM).name) for $filter" }
            Write-Output $returntag
        }#elif end
    
    }#process end
    End{}
}#Test-VmTag end

<#
.Synopsis
   Checks all VMs for a tag and returs the VMs that have it. 
.DESCRIPTION
   Uses a string for the tag and returns all the VMs that have that tag. 
.EXAMPLE
   Get-VMbyTag "IIS"

#>
function Get-VMbyTag
{
    [CmdletBinding()]
    [OutputType([psobject[]])]
    Param(
        # A string variable. String can be passed through the pipeline. 
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [string]$Tag
    )

    Begin{}
    
    Process{

        
        #Assigns vms have the tag to array and returns the array
        Write-Verbose "Checking Tag: $tag  On the VMs"
        Get-VM | foreach { if (Test-VMTag -Filter $Tag -VM $_ ) {Write-Output $_}}
        

    }#end process
    
    End{}
}# get-Vmbytag end

<#
.Synopsis
    Function will add a tag to a VM.
.DESCRIPTION
    Function will add a tag to a VM Object. If the tag is already present it will not add it again. 
    If the VM has not been initialized for Tags, it will automatically do it. 
    The fucntion can accept an array of strings for multiple tags.
.EXAMPLE
   Add-VMTag (Get-VM Jenkins) -Tag "IIS"
.EXAMPLE
   Add-VMTag $VM -Tag ("IIS","SQL","Auto-Tag")
#>
function Add-VMTag
{
    [CmdletBinding()]
    Param(
         #VM object. The output of Get-VM will work. Accepts the value from the pipeline.
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [Microsoft.HyperV.PowerShell.VirtualMachineBase]$VM,

        # A String or an array of Strings.
        [string[]]$Tag
    )

    Begin{}
    
    Process{
        #adds the line for tags if not found
        if ((Check-VMTags $vm) -eq $false){
            write-verbose "Tags Not initialized on $(($VM).name). Initializing"
            Initialize-VMTags $vm
            }
    
        #Looks for the line with tags on the note field
        $notes = $vm.Notes
        $split = $notes -split "`n"
        $raw = $split | Select-String -SimpleMatch -Pattern "Tags:"
    
        #if tags are empty creates empty Arraylist
        #if tags are present, creates array list with the tags
        [Array]$tags = (Get-VMTags($vm)).tags
        [System.Collections.ArrayList]$taglist = $tags
        if ($tags.trim(" ") -eq ""){
            $taglist.remove("")
        }
        #foreach loop so each tag gets added to array list
        #prevents duplicates from being added
        $tag | foreach {
            if (-not (Test-VMTag -VM $vm -Filter $_)){
                if (-not($_.Trim(" ") -eq "" )){
                    $taglist.Add($_) | out-null
                    write-verbose "Adding tag, $_ on $(($VM).name)"
                }
            }else { Write-verbose "$_ has been added already for $(($VM).Name) "} 
        }
    
        #Joins array list back into a string
        #replaces line in notes with new string
        #Writes new notes into VM
        $tagline = $taglist -join "; "
        $split[($raw.LineNumber -1)] = "Tags: "+ $tagline
        $newnotes = $split -join "`n"
        set-vm $vm -Notes $newnotes      
        Sort-VMTags $vm
    }
    End{}
}#add-vmtag end

<#
.Synopsis
    Function will remove a tag(s) to a VM.
.DESCRIPTION
    Function will remove a tag to a VM Object. If the tag is not already present it will not try to remove it again. 
    The fucntion can accept an array of strings for removing multiple tags.
.EXAMPLE
   Remove-VMTag (Get-VM Jenkins) -Tag "IIS"
.EXAMPLE
   Remove-VMTag $VM -Tag ("IIS","SQL","Auto-Tag")
#>
function Remove-VMTag
{
    [CmdletBinding()]
        Param(
         #VM object. The output of Get-VM will work. Accepts the value from the pipeline.
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [Microsoft.HyperV.PowerShell.VirtualMachineBase]$VM,

        # A String or an array of Strings.
        [string[]]$Tag
    )

    Begin{}
    Process{
            
        #ends function if no tags found
        if ((Check-VMTags $vm) -eq $false){
            
            }else{
                #Looks for the line with tags on the note field
                $notes = $vm.Notes
                $split = $notes -split "`n"
                $raw = $split | Select-String -SimpleMatch -Pattern "Tags:"
    
    
                #creates array list with the tags
                [Array]$tags = (Get-VMTags($vm)).tags
                [System.Collections.ArrayList]$taglist = $tags

                #foreach loop for every tag to be removed
                $tag | foreach {
                    #removes tag if it is "" else removes if it is a tag of that VM
                    if  ($_ -eq " "){
                        $taglist.Remove(" ") | out-null
                        Write-Verbose "Removing Empty Tag on $(($VM).Name)"
                    }elseif ($_ -eq "" ){
            
                        $taglist.Remove("") | out-null
                        Write-Verbose "Removing Empty Tag on $(($VM).Name)"
                    }elseif ( Test-VMTag -VM $vm -Filter $_){
                        #assign to variable to use $_ on double pipe
                        $a = $_
                        #clone created to prevent errors when modifyint itself
                        $Taglist.Clone() | Select-String -Pattern $_ | foreach { if( $a -eq $_){
                                                                                        $taglist.Remove($_.ToString())| out-null 
                                                                                        Write-Verbose "Removing $($_.tostring()) on $(($VM).Name)"
                                                                                        }
                                                                                        
                                                                                }
                    } 
                }#end tag foreach
    
                #Joins array list back into a string
                #replaces line in notes with new string
                #Writes new notes into VM 
                $tagline = $taglist -join "; "
                $split[($raw.LineNumber -1)] = "Tags: "+ $tagline
                $newnotes = $split -join "`n"
                set-vm $vm -Notes $newnotes      
            }
    }
    End{}
}#end Remove-vmtag

<#
.Synopsis
    Sorts the Tags in a VM in ascending order. 
.DESCRIPTION
    Sorts the Tags in a VM in ascending order. Uses the sort-object Cmlet 
.EXAMPLE
   Sort-Object (Get-VM Jenkins)
#>
function Sort-VMTags
{
    [CmdletBinding()]
    Param(
         #VM object. The output of Get-VM will work. Accepts the value from the pipeline.
        [Parameter(Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [Microsoft.HyperV.PowerShell.VirtualMachineBase]$VM
    )

    Begin{}
    Process{
            #ends function if no tags found
            if ((Check-VMTags $vm) -eq $false){
                
            }else {
                #gets and sorts the tags
                $Tags = (Get-VMTags ($vm)).tags
                $tags = $tags | Sort-Object 
    
    
                #gets the line the Tags are on the notes
                #replaces it with the ordered tags
                $notes = $vm.Notes
                $split = $notes -split "`n"
                $raw = $split | Select-String -SimpleMatch -Pattern "Tags:"
                $tagline = $tags -join "; "
                $split[($raw.LineNumber -1)] = "Tags: "+ $tagline
                $newnotes = $split -join "`n"
                set-vm $vm -Notes $newnotes  
            }   

    }#process end
    End{}
}# sort-vmtags end

<#
.Synopsis
   Checks if Tags are present on a VM. Returns true if if does false if not.
.DESCRIPTION
   Long description
.EXAMPLE
   Check-VMTags (Get-VM Jenkins)
#>
function Check-VMTags
{
    [CmdletBinding()]
    [OutputType([boolean])]
    Param(
        #VM object. The output of Get-VM will work. 
        [Parameter(
                   Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [Microsoft.HyperV.PowerShell.VirtualMachineBase]$VM
    )

    Begin{}

    Process{
    
        #looks for a match for "Tags"
        #returns true if found
        $notes = $vm.notes
        $split = $notes -split "`n"
        $match = $split | Select-String -SimpleMatch -Pattern "Tags:" 
        if ($match -ne $null){
            Write-Output $true

        }else {
            Write-Output $false
               }

    }
    End{}
}#check-vmtags end

<#
.Synopsis
   Deletes tags that consist of just Spaces or are empty
.DESCRIPTION
   Deletes tags that consist of just Spaces or are empty
.EXAMPLE
   Delete-VMEmptyTags (Get-VM Jenkins)
#>
function Delete-VMEmptyTags
{
    [CmdletBinding()]
    Param(
        #VM object. The output of Get-VM will work. 
        [Parameter(
                   Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [Microsoft.HyperV.PowerShell.VirtualMachineBase]$VM
    )
    

    Begin{}
    Process{
        #checks for empty tags
        if (-not (Test-VMTag -vm $VM -filter "")){
            
        }else{
        #calls remove-vmtag for each VM and for each empy tag
        Write-Verbose "Removing empty tags from $(($VM).NAME)"
        (Get-VMTags $vm).tags | foreach {if ($_ -eq ""){Remove-VMTag -vm $vm -Tag "" }}
        }
    }
    End{}
}#Delete-VMEmptyTags end

<#
.Synopsis
   Completele deinitializes the Tags on the Notes Field.
.DESCRIPTION
   This function will remove the tags field on the notes field for the VM. It will not delete any other data on the Notes field. 
.EXAMPLE
   Clear-VMAllTags (Get-VM "Jenkins")
#>
function Clear-VMAllTags
{
    [CmdletBinding()]
    Param
    (
       #VM object. The output of Get-VM will work. 
        [Parameter(
                   Mandatory=$true,
                   ValueFromPipeline=$true,
                   Position=0)]
        [Microsoft.HyperV.PowerShell.VirtualMachineBase]$VM
    
    )

    Begin{}
    Process{
        #check for tags    
        if((Check-VMTags($vm)) -eq $false){
        }else{
        
            #gets the notes field and separates them into lines
            #gets the line number where 
            Write-verbose "Clearing and deinitializing all tags for $(($VM).Name)"
            $notes = $vm.Notes
            $split = $notes -split "`n"
            $raw = $split | Select-String -SimpleMatch -Pattern "Tags:"
            [System.Collections.ArrayList]$notelist = $split

            #replaces note field
            $notelist.Remove($raw.ToString())
            $join = $notelist.ToArray() -join("`n")
    
            if ($join -eq "" ){
                set-vm -vm $vm -Notes " "
            }else{
                set-vm -vm $vm -Notes $join 
            }
         
        }



    }
    
    
    End{}
}#Clear-VMAllTags  end 
<#
.Synopsis
   Initializes the Tags on the Notes Field.
.DESCRIPTION
   This function will Add the tags field on the notes field for the VM. It will not change any other data on the Notes field. 
.EXAMPLE
   Initialize-VMTags (Get-VM "Jenkins")
#>

function Initialize-VMTags {
    [CmdletBinding()]
    Param(
        [Parameter(
                    Mandatory= $true,
                    valuefrompipeline= $True,
                    Position= 0)]
        [Microsoft.HyperV.PowerShell.VirtualMachineBase]$VM


    )
    Begin{}
    Process{
        #check if a tag line exits and returns if it is
   
        if(check-vmtags($vm)){
             
        }else{

            #separates all lines into a array list
            #adds the line into the array list
            #returns and writes it back into the notes field
            $notes = $vm.Notes
            $split = $notes -split "`n"
    
    
            [System.Collections.ArrayList]$notelist = $split
            if ($notes -eq ""){
                $notelist.remove("")
            }
            $notelist.Add("Tags:") | Out-null
            $join = $notelist.ToArray() -join("`n")
            set-vm $vm -Notes $join
        }



    }

    End{}



}#Initialize-VMTags end