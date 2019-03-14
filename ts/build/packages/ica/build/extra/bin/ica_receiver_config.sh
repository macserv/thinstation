#! /bin/sh

. "${TS_GLOBAL}"


LOGGERTAG="ica_receiver_config.sh"
ICA_ROOT=/opt/Citrix/ICAClient
ICA_STOREBROWSE=$ICA_ROOT/util/storebrowse
ICA_SELFSERVICE=$ICA_ROOT/selfservice
SETUP_DONE_CHECK_FILE=${HOME}/.ICAClient/.self_service_setup_done



add_stores_using_provisioning_file()
{
	[ -n "${ICA_RECEIVER_PROVISIONING_CR_FILE}" ] || return

	receiver_cr_path="${HOME}/${ICA_RECEIVER_PROVISIONING_CR_FILE}"
	logger --stderr --tag $LOGGERTAG "Adding Citrix Receiver stores using the ICA_RECEIVER_PROVISIONING_CR_FILE specified at this path: ${receiver_cr_path}"

	if ! [ -f "${receiver_cr_path}" ] ; then
		logger --stderr --tag $LOGGERTAG "The specified provisioning file does not exist."
		return
	fi

	added_store=$($ICA_STOREBROWSE --addcr "${receiver_cr_path}")
	
	if [ $? -ne 0 ] || [ -z "${added_store}" ] ; then
		logger --stderr --tag $LOGGERTAG "An error occurred while adding stores, or the provisioning file contained no stores."
		return
	fi 
	
	logger --stderr --tag $LOGGERTAG "Added Store: ${added_store}"
}


	####
	# Check if setup is done already.
	##
	
	if [ -e "${SETUP_DONE_CHECK_FILE}" ] ; then
	
		logger --stderr --tag $LOGGERTAG "Starting Citrix Receiver Self-Service (setup was already done)."
		exec ${ICA_SELFSERVICE} --icaroot ${ICA_ROOT}
		
	fi


	####
	# Start Self Service configuration.
	##

	logger --stderr --tag $LOGGERTAG "Setting up Citrix Receiver Self-Service."
	

	# Kill storebrowse and other processes that might intefear...
	killall storebrowse AuthManagerDaemon ServiceRecord selfservice


	# Add StoreFront stores using a supplied CR file
	add_stores_using_provisioning_file
	

	# Add StoreFront stores by login point address.
	let x=1
	while [ -n "$(eval echo '$ICA_RECEIVER_STOREFRONT_'$x'_ADDRESS')" ]; do
		# First add the store
		$ICA_STOREBROWSE --addstore "$(eval echo '$ICA_RECEIVER_STOREFRONT_'$x'_ADDRESS')"
	
		# Secondly, check if we should change the Default Gateway for the added store
		#     You can find the info if you go in to Receiver --> Preferences, the tab Accounts, press Edit and
		#     there you find the "Server URL:" and "Default Gateway:" (droplist)
		#
		#     That info should be defined as ICA_RECEIVER_STOREFRONT_0_DEFAULT_GATEWAY="'Default Gateway Name as in the droplist' 'Server URL (the one that ends with /discovery)'"
		#     e.g. in the configuration files:
		#          ICA_RECEIVER_STOREFRONT_0_DEFAULT_GATEWAY="'Internal Gateway' 'https://storefront.myinternaldomain.com/citrix/myStoreName/discovery'"
		#          (note that name and url are within single quotes (') and everything is enclosed with double quotes (")
		#
		#     If the information does display completly in the application GUI you can see the information by running
		#          /opt/Citrix/ICAClient/util/storebrowse --liststores
		#
		if [ -n "$(eval echo '$ICA_RECEIVER_STOREFRONT_'$x'_DEFAULT_GATEWAY')" ]; then
			# First, extract the value into a temporary variable
			gateway_value=$(eval echo '$ICA_RECEIVER_STOREFRONT_'$x'_DEFAULT_GATEWAY')
		
			# Now, run the full command.
			$ICA_STOREBROWSE --storegateway "$gateway_value"
		fi
		let x=x+1
	done


	# Check if we set a specific default StoreFront store
	if [ -n "${ICA_RECEIVER_STOREFRONT_DEFAULT}" ]; then
		$ICA_STOREBROWSE --configselfservice DefaultStore="$ICA_RECEIVER_STOREFRONT_DEFAULT"
	fi


	# Check Receiver Preference for Reconnect at Logon behavior
	if is_enabled "${ICA_RECEIVER_RECONNECT_ON_LOGON}"; then
		$ICA_STOREBROWSE --configselfservice ReconnectOnLogon=True
	else
		$ICA_STOREBROWSE --configselfservice ReconnectOnLogon=False
	fi


	# Check Receiver Preference for Reconnect at Launch Or Refresh behavior
	if is_enabled "${ICA_RECEIVER_RECONNECT_ON_LAUNCH_OR_REFRESH}"; then
		$ICA_STOREBROWSE --configselfservice ReconnectOnLaunchOrRefresh=True
	else
		$ICA_STOREBROWSE --configselfservice ReconnectOnLaunchOrRefresh=False
	fi


	# Check Receiver Preference for Display Desktops in window/full screen mode
	if is_enabled "${ICA_RECEIVER_DISPLAY_DESKTOPS_IN_FULLSCREEN}"; then
		$ICA_STOREBROWSE --configselfservice SessionWindowedMode=False
	else
		$ICA_STOREBROWSE --configselfservice SessionWindowedMode=True
	fi


	# Check Receiver Preference for SharedUserMode
	if is_enabled "${ICA_RECEIVER_SHARED_USER_MODE}"; then
		$ICA_STOREBROWSE --configselfservice SharedUserMode=True
	else
		$ICA_STOREBROWSE --configselfservice SharedUserMode=False
	fi


	# Check Receiver Preference for FullscreenMode
	if is_in_list "${ICA_RECEIVER_FULLSCREEN_MODE}" 0 1 2; then
		$ICA_STOREBROWSE --configselfservice FullscreenMode="${ICA_RECEIVER_FULLSCREEN_MODE}"
	elif is_enabled "${ICA_RECEIVER_FULLSCREEN_MODE}" ; then
		$ICA_STOREBROWSE --configselfservice FullscreenMode=1
	else
		$ICA_STOREBROWSE --configselfservice FullscreenMode=0
	fi


	# Check Receiver Preference for SelfSelection
	if is_enabled "${ICA_RECEIVER_SELF_SELECTION}"; then
		$ICA_STOREBROWSE --configselfservice SelfSelection=True
	else
		$ICA_STOREBROWSE --configselfservice SelfSelection=False
	fi


	# Add extra storebrowse configselfservice options
	let x=1
	while [ -n "$(eval echo '$ICA_RECEIVER_STOREFRONT_STOREBROWSE_CONFIGSELFSERVICE_EXTRA_'$x)" ]; do
		$ICA_STOREBROWSE --configselfservice "$(eval echo '$ICA_RECEIVER_STOREFRONT_STOREBROWSE_CONFIGSELFSERVICE_EXTRA_'$x)"
		let x=x+1
	done


	logger --stderr --tag $LOGGERTAG "Citrix Receiver store list after configuration:\n$($ICA_STOREBROWSE --liststores)"




	####
	# Start Receiver clear credentials job
	##

	# See if we shall schedule a job to clear the users credentials in Citrix Receiver
	if is_enabled "${ICA_RECEIVER_CLEAR_CREDENTIALS_WHEN_SESSION_LAUNCHED}" || is_enabled "${ICA_RECEIVER_CLEAR_CREDENTIALS_AFTER_SESSION_ENDS}" ; then
		# Set the default check interval to 5 minutes
		CHECK_INTERVAL=5

		# Use the specified time if we have that defined. (cast it into an integer)
		if [ -n "${ICA_RECEIVER_CLEAR_CREDENTIALS_CHECK_INTERVAL}" ]; then
			CHECK_INTERVAL=$ICA_RECEIVER_CLEAR_CREDENTIALS_CHECK_INTERVAL
		fi
		
		# See if we shall schedule a job to clear the users credentials in Citrix Receiver
		# (cast it to an integer so if it's not defined it will return 0)
		if [ $((CHECK_INTERVAL)) -gt 0 ]; then
			logger --stderr --tag $LOGGERTAG "Adding ica_receiver_clear_credentials.sh with $((ICA_RECEIVER_CLEAR_CREDENTIALS_CHECK_INTERVAL)) minutes interval to crontab."
			
			if ! crontab -l | grep -q 'ic2a_receiver_clear_credentials.sh'; then
				echo "*/$((CHECK_INTERVAL)) * * * * /bin/ica_receiver_clear_credentials.sh" >> /tmp/crontab
				crontab /tmp/crontab
			fi
		else
			logger --stderr --tag $LOGGERTAG "ICA_RECEIVER_CLEAR_CREDENTIALS_CHECK_INTERVAL is 0 although ICA_RECEIVER_CLEAR_CREDENTIALS_WHEN_SESSION_LAUNCHED and/or ICA_RECEIVER_CLEAR_CREDENTIALS_AFTER_SESSION_ENDS are defined. No job and will not be added to crontab!"
		fi
	fi
	
	
	
	
	####
	# Mark setup complete
	##
    
	touch "${SETUP_DONE_CHECK_FILE}"




	####
	# Start Citrix Receiver
	##
	
	# Wait a moment before we start the Citrix Receiver, to allow configuration to be fully applied by `storebrowse`.
	sleep 2
	
	logger --stderr --tag $LOGGERTAG "Starting Citrix Receiver Self-Service (post-setup)."
	exec ${ICA_SELFSERVICE} --icaroot ${ICA_ROOT}





