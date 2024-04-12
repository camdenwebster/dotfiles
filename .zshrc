########## VM Operations ##########
# Delete and clone a Tart VM given the OS version (i.e. 'sonoma', 'ventura', 'monterey')
clean-vm () {
	tart delete $1-edit
	tart clone $1-base $1-edit
}

# Run a Tart VM given the OS version (i.e. 'sonoma', 'ventura', 'monterey')
run-vm () {
	tart run $1-edit
}

ssh-vm () {
	vm=$1-edit
	ssh admin@$(tart ip $vm)
}

########## Defaults Operations ##########
# Copy the folder of configs over to a test machine
copy-configs () {
	scp -R * $1@$2
}

# Read the Jamf Connect Login plist at /Library/Preferences/com.jamf.connect.login.plist
alias read-login-config='defaults read /Library/Preferences/com.jamf.connect.login.plist'

# Read the Jamf Connect plist at /Library/Preferences/com.jamf.connect.plist
alias read-menubar-config='defaults read /Library/Preferences/com.jamf.connect.plist'

# Clear the login config
alias delete-login-config='sudo defaults delete /Library/Preferences/com.jamf.connect.login.plist'

# Clear the menubar config at both the user level and system level
delete-menubar-config () { 
	defaults delete /Library/Preferences/com.jamf.connect.plist
	defaults delete /Users/$USER/Library/Preferences/com.jamf.connect.plist
	defaults delete /Users/$USER/Library/Preferences/com.jamf.connect.state.plist
}

# Write a preference key to the Login domain
write-login-string () {
	defaults write /Library/Preferences/com.jamf.connect.login.plist $1 $2
}

write-login-int () {
	defaults write /Library/Preferences/com.jamf.connect.login.plist $1 -int $2
}

write-login-bool () {
	defaults write /Library/Preferences/com.jamf.connect.login.plist $1 -bool $2
}


# Write a preference key to the Menubar domain
write-menubar-string () {
	defaults write /Library/Preferences/com.jamf.connect.plist $1 -dict-add $2 $3
}

write-menubar-int () {
        defaults write /Library/Preferences/com.jamf.connect.plist $1 -dict-add $2 -int $3
}

write-menubar-bool () {
        defaults write /Library/Preferences/com.jamf.connect.plist $1 -dict-add $2 -bool $3
}

install-config () {
	cp $1 /Library/Preferences/
	defaults read /Library/Preferences/$1
}
