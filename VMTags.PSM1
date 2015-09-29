
<#Retuns an array of the tags on a Virtual Machine
#Params for $vm is a Virtual machine object
#Returns an array for tags or Null if no tags are found
#>
function Get-VMTags ($vm){
    
    #Returns Null if no tags are found         
    if((check-vmtags($vm)) -eq $false){
        #write-host "No tag found"
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

    return $tags

}

<#Tests if a tag is found on a VM
#Parameters are a VM object and a string for the tags to test
#Returns a boolean if the tag is found or not
#>
function Test-VMTag ($VM, $Filter) {
    
    $tags = Get-VMTags -vm  $VM
    
    #returns false if no tags are present
    if($tags -eq $null){
        return $false
    }
    
    #loops through the tags and returns true if match is made
    $returntag = $false 
    $tags | foreach { if ($_ -eq $filter) {
                        $returntag = $true
                        return
                        } 
                    }
    return [boolean]$returntag
}

<#Searches for VMs with a specific tag
#Parameter is a string for the tag
#Returns an array of VM objects
#>
Function Get-VMbyTag ($Tag) {

   #Assigns vms have the tag to array and returns the array
    $taggedVM = Get-VM | foreach { if (Test-VMTag -Filter $Tag -VM $_ ) {$_}}
    Return $taggedVM

}

<#Adds a tag or tags to a VM
#Parameters are a VM object and string array for tags
#Does not retun anything
#>
Function Add-VMTag ($VM, [Array]$Tag){
    
    #adds the line for tags if not found
    if ((Check-VMTags $vm) -eq $false){
        Initialize-VMTags $vm
        }
    
    #Looks for the line with tags on the note field
    $notes = $vm.Notes
    $split = $notes -split "`n"
    $raw = $split | Select-String -SimpleMatch -Pattern "Tags:"
    
    #if tags are empty creates empty Arraylist
    #if tags are present, creates array list with the tags
    [Array]$tags = Get-VMTags($vm)
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
            }
        }else { Write-host "$_ has been added already."} 
    }
    
    #Joins array list back into a string
    #replaces line in notes with new string
    #Writes new notes into VM
    $tagline = $taglist -join "; "
    $split[($raw.LineNumber -1)] = "Tags: "+ $tagline
    $newnotes = $split -join "`n"
    set-vm $vm -Notes $newnotes      
    Sort-VMTags $vm
    return
    
}

<#Removes a tag or tags to a VM
#Parameters are a VM object and string array for tags
#Does not retun anything
#>
Function Remove-VMTag ($VM, [Array]$Tag){
    
    #ends function if no tags found
    if ((Check-VMTags $vm) -eq $false){
        Write-host "No Tags found"
        Return
        }
    #Looks for the line with tags on the note field
    $notes = $vm.Notes
    $split = $notes -split "`n"
    $raw = $split | Select-String -SimpleMatch -Pattern "Tags:"
    
    
    #creates array list with the tags
    [Array]$tags = Get-VMTags($vm)
    [System.Collections.ArrayList]$taglist = $tags

    #foreach loop for every tag to be removed
    $tag | foreach {
        #removes tag if it is "" else removes if it is a tag of that VM
        if  ($_ -eq " "){
            $taglist.Remove(" ") | out-null
        }elseif ($_ -eq "" ){
            
            $taglist.Remove("") | out-null
        
        }elseif ( Test-VMTag -VM $vm -Filter $_){
            #assign to variable to use $_ on double pipe
            $a = $_
            #clone created to prevent errors when modifyint itself
            $Taglist.Clone() | Select-String -Pattern $_ | foreach { if( $a -eq $_){$taglist.Remove($_.ToString())| out-null }  }
        } 
    }#end tag foreach
    
    #Joins array list back into a string
    #replaces line in notes with new string
    #Writes new notes into VM 
    $tagline = $taglist -join "; "
    $split[($raw.LineNumber -1)] = "Tags: "+ $tagline
    $newnotes = $split -join "`n"
    set-vm $vm -Notes $newnotes      
    return

}

<#Sorts the Tags in acsending order for a VM
#Parameters is a VM object
#Does not retun anything
#>
Function Sort-VMTags ($VM){
    
    #ends function if no tags found
    if ((Check-VMTags $vm) -eq $false){
        Write-host "No Tags foung"
        Return
    }

    #gets and sorts the tags
    $Tags = Get-VMTags ($vm)
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


<#Checks whethes there is a Tags: line in the notes field
#Param is an VM object
#Returs true if there is, false if not
#>
function Check-VMTags ($VM){

    #looks for a match for "Tags"
    #returns true if found
    $notes = $vm.notes
    $split = $notes -split "`n"
    $match = $split | Select-String -SimpleMatch -Pattern "Tags:" 
    if ($match -ne $null){
        return $true
    }else {return $false}
}

<#Looks for any tags that are empty spaces and calls the Remove-Tag function to delete them
#Param is a VM object
#>
function Delete-VMEmptyTags ($vm){
    
   
    #chacks for empty tags
    if (-not (Test-VMTag -vm $VM -filter "")){
        write-host "No empty tags found."
        return
    }
    #calls remove-vmtag for each VM and for each empy tag
    Get-VMTags $vm | foreach {if ($_ -eq ""){Remove-VMTag -vm $vm -Tag "" }}
    
}


<#Looks for the line in notes with tags and removes it completely
#Param is a VM object
#>
function Clear-VMAllTags ($vm){
    #check for tags    
    if((Check-VMTags($vm)) -eq $false){
        Return
    }
    
    #gets the notes field and separates them into lines
    #gets the line number where 
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
    return



}

<#Looks for the line in notes with tags and if not found, it will create a new one
#Param is a VM object
#>
function Initialize-VMTags ($vm){
        
    #check if a tag line exits and returns if it is
   
    if(check-vmtags($vm)){
         Write-Host "Tags found"
         Return
    }

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
    return



}


