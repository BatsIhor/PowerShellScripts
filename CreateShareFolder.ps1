#NET SHARE Shared=C:Shared /GRANT:everyone,FULL

#net 'share' 'Shared=c:\Shared'  '/Grant:Everyone,FULL'


function New-Share ($foldername, $sharename) { 
    if (!(test-path $foldername)) { 
        new-item $foldername -type Directory } 

    if (!(get-wmiObject Win32_Share -filter “name='$sharename'”)) { 
        $shares = [WMICLASS]”WIN32_Share”

        if ($shares.Create($foldername, $sharename, 0).ReturnValue -ne 0) {
            throw "Failed to create file share '$sharename'"
        }
    }    
}

New-Share "c:\ModernShare" "ModernShare"