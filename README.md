# Description
This script is used to create EMC/Dell XIO snapshots used for backups or SUP refreshes of the Epic EMR system. It could be used for other purposes as well.

A snapshot is kept for each day of the week (Monday, Tuesday, Wednesday, etc) to offer multiple restore points. A RW snaphsot as well as a Read Only snapshot is already created. A SUP snapshot is created as well. The below is a summary of the snapshots created:

	The script will create the following SnapShot sets:
		CGName-SUP	== For SUP (Read/Write)
		CGName-RW	== Clone mounted for backups (Read/Write)
		CGName-RO	== Extra Clone (Read-Only)
		CGName-MON	== Clone refreshed every Monday
		CGName-TUE	== Clone refreshed every Tuesday
		CGName-WED	== Clone refreshed every Wednesday
		CGName-THU	== Clone refreshed every Thursday
		CGName-FRI	== Clone refreshed every Friday
		CGName-SAT	== Clone refreshed every Saturday
		CGName-SUN	== Clone refreshed every Sunday

The script automatically creates the necessary initial snapshot sets, as long as the consistency group is created ahead of time.

# Installation

On RHEL, the following commands will ensure all required modules are installed. It has been a while since I have done a fresh install of this script, so please let me know if anything has changed.

	yum install perl
	yum install perl-libwww-perl
	yum install perl-MailTools
	yum install perl-CPAN
	perl -MCPAN -e "install Mail::Sendmail"
	yum install perl-LWP-Protocol-https.noarch

# Configuration

You will need to modify several variables within the script for it to function in your environment. They are listed below.

Line 16 ($xms): Configure the XMS server managing the XIO.

Line 19 ($clname): Define the cluster name. You can find this by logging into XMS.

Line 22 ($username): Username which has 'configuration' role in XMS. I recommend this be different than your admin account and be specific for this purpose.

Line 25 ($password): Password for the above account.

Line 28 ($cgname): The consistency group name for the LUNS you wish to snapshot. This is required, as Epic will have multiple LUNS supporting the environment.

Line 31 ($mailto): The email address you want output to go to when NOT using the --no-mail option. By default, the script sends all output to email. Separate multiple addresses with a semicolon (;).

Line 34 ($mailfrom): The email address automated email should be sourced FROM.

Line 37 ($mailsubject): The subject for automated emails.

Line 40 ($logfile): The path where the log file should be stored.

In the freeze_cache() function, line 201, modify this command to suite your environment. You'll need to have key-based SSH authentication working for the user calling the script if you are running this script from a server other than the server running Cache.

In the thaw_cache() function, line 217, modify this command to suite your environment. You'll need to have key-based SSH authentication working for the user calling the script if you are running this script from a server other than the server running Cache.

In the unmount_mount function, if you want to unmount and re-mount the clone (useful for a SUP refresh), you'll need to modify lines 387 & 388 for your filesystems. 

# First Run

After the script is created, you'll want to run the script with the --create-snapshot-sets option first. This will create all of the initial snapshots!

# Useful options

Useful for refreshing SUP via ENVCopy. This WILL unount and re-mount the file systems listed in the script

	./xio_epic_snap.pl --sup-only

Refresh all clones EXCEPT SUP and do not remount any file systems

	./xio_epic_snap.pl --all --no-mount --no-sup

To call from your backup start command. This will refresh ALL snapshots excep SUP and will remount the file systems listed in the script.

	./xio_epic_snap.pl --all --no-sup

# Feedback

Please let me know if you are using this script. I'd be great to know others are using it! Also let me know if you have any qustions or issues.

# Command line options

XIO Cloning Tool for Epic
Version 2.0

usage:

	--create-snapshot-sets	This will create the appropriate SnapShot sets on the XIO
	--sup-only		This will refresh the SUP SnapShot set ONLY
	--all			This will refresh ALL SnapShot sets
	--no-freeze		Do not Freeze and Thaw Cache
	--no-mail		By default, the script emails its output. This will display
				output on the CLI.
	--no-sup		Must be used in combination with --all, but skips the SUP
				SnapShot. Useful for restarting backups during the day.
	--no-mount		Do not unmount/remount file systems.
	--help			This help screen
	

Basic Info:
	You must configure the variables within the script first.

	The script will create the following SnapShot sets:
		CGName-SUP	== For SUP (Read/Write)
		CGName-RW	== Clone mounted for backups (Read/Write)
		CGName-RO	== Extra Clone (Read-Only)
		CGName-MON	== Clone refreshed every Monday
		CGName-TUE	== Clone refreshed every Tuesday
		CGName-WED	== Clone refreshed every Wednesday
		CGName-THU	== Clone refreshed every Thursday
		CGName-FRI	== Clone refreshed every Friday
		CGName-SAT	== Clone refreshed every Saturday
		CGName-SUN	== Clone refreshed every Sunday

