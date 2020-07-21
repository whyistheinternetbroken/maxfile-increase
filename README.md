# maxfile-increase
In ONTAP, volumes have a set number of maximum inodes, which limits the number of files and folders that can be placed in a volume. If that number hits 100%, clients will report the volume is "out of space," even if capacity seems to be fine. In the ONTAP cluster, you will see event logs that show the volume is "out of inodes."

The maximum number of inodes/files is controlled with the -files option in the ONTAP CLI. The default number of inodes is dependent on the total size of the volume. For details on maxfiles, see TR-4571:

https://www.netapp.com/us/media/tr-4571.pdf

To view the maximum files/files used, run this command from the ONTAP CLI:

:*> vol show -vserver SVM -volume volname -fields files,files-used

You can also get a percent-used value with:

::*> df -i volname

ONTAP has no built-in automation to increase the inode counts and it's generally recommended to avoid increasing the maximum files to the highest value possible. These scripts help automate increase of maxfiles in ONTAP to avoid "Out of Inodes" errors. 

Available for REST (ONTAP 9.6 and later) and for use with ActiveIQ Unified Manager.
NOTE: SSH output not easily parsed; ZAPI being deprecated in future releases.

* The REST script can be run with a cron schedule to periodically check the amount of used inodes against the total inodes with a configurable threshold and then take corrective action to increase the maximum inode count by a specified percentage.

* The ActiveIQ Unified Manager script can be used in conjunction with ActiveIQ's built-in inode monitoring capabilities.
