# About the maxfile-monitor script

In ONTAP, volumes have a set number of maximum inodes, which limits the number of files and folders that can be placed in a volume. If that number hits 100%, clients will report the volume is "out of space," even if capacity seems to be fine. In the ONTAP cluster, you will see event logs that show the volume is "out of inodes."

The maximum number of inodes/files is controlled with the -files option in the ONTAP CLI. The default number of inodes is dependent on the total size of the volume. 

For details on maxfiles:  
* [FlexGroup best practices TR](https://www.netapp.com/us/media/tr-4571.pdf)  
* [FAQ - ONTAP maximum number of inodes (maxfiles)](https://kb.netapp.com/on-prem/ontap/Ontap_OS/OS-KBs/FAQ_ONTAP_maximum_number_of_inodes_maxfiles)  

To view the maximum files/files used, run this command from the ONTAP CLI:
```
:*> vol show -vserver SVM -volume volname -fields files,files-used
```

You can also get a percent-used value with:

```
::*> df -i volname
```


ONTAP has no built-in automation to increase the inode counts and it's generally recommended to avoid increasing the maximum files to the highest value possible. These scripts help automate increase of maxfiles in ONTAP to avoid "Out of Inodes" errors by monitoring the % used and increasing in smaller increments.

Available for REST (ONTAP 9.6 and later).

* The REST script can be run with a cron schedule to periodically check the amount of used inodes against the total inodes with a configurable threshold and then take corrective action to increase the maximum inode count by a specified percentage.

## Setting variables

The following variables need to be set in the script to ensure proper functionality.

* Cluster DNS name or IP address (CLUSTER)
  - This is used to connect REST API calls
* Volume name (VOLUME)
* Storage virtual machine name (SVM)
* Maxfiles threshold (MAXFILE_THRESHOLD)
  - This configures the maxfile % used threshold for the monitor to kick off the maxfile increase
* Maxfiles percent increase (MAXFILE_PERCENT_INCREASE)
  - The % of increase for maxfiles
* Authorization token (AUTH_TOK)
  - The auth token for REST calls
* Log file path (LOG_PATH)

## Getting an auth token for REST
To authenticate to the cluster to run REST API calls, you will need to generate an auth token.

The following link covers this process:
[Overview of the ONTAP OAuth 2.0 implementation in ONTAP](https://docs.netapp.com/us-en/ontap/authentication/overview-oauth2.html#implementation-and-configuration)  

## Using docker to run script as a container
You can run the script as a container by doing the following.

1. Clone the repository
```
git clone https://github.com/whyistheinternetbroken/maxfile-increase
```
3. Build the container by running the command in the folder with the Docker file
```
docker build -t maxfile-monitor .
```
3. Run the container with the following command
```
docker run --rm maxfile-monitor
```

### Example output of script:
```
Fetching volume maxfiles information...

  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   265  100   265    0     0   4602      0 --:--:-- --:--:-- --:--:--  4649

====================================================================================================

--------------------------------------------------
Script started at: Mon Apr  7 14:39:06 UTC 2025
--------------------------------------------------

ONTAP VOLUME MAXFILES INFORMATION
-------------------------------------------------------------------------------------------------------
| Volume Name  | Volume UUID                          | Total files | Total files used | % Files used |
-------------------------------------------------------------------------------------------------------
| fvfiles      | f23a19cb-fac1-11eb-a4b1-d039ea1b5c57 | 35954675    | 34242546         | 95           |
-------------------------------------------------------------------------------------------------------

********************************************WARNING********************************************
 95% inodes used for volume "fvfiles" is greater than the configured maxfile threshold of 80%.
***********************************************************************************************

Maxfiles value for the volume will be increased by 5%.

Fetching updated volume maxfiles information...

  % Total    % Received % Xferd  Average Speed   Time    Time     Time  Current
                                 Dload  Upload   Total   Spent    Left  Speed
100   265  100   265    0     0   4647      0 --:--:-- --:--:-- --:--:--  4732

--------------------------------------------------
| Total inodes increased by       |      1797733 |
| New maxfiles value for volume   |     37752408 |
| Percent increase                |           5% |
--------------------------------------------------

NEW ONTAP VOLUME MAXFILES INFORMATION
-------------------------------------------------------------------------------------------------------
| Volume Name  | Volume UUID                          | Total files | Total files used | % Files used |
-------------------------------------------------------------------------------------------------------
| fvfiles      | f23a19cb-fac1-11eb-a4b1-d039ea1b5c57 | 37752396    | 34242546         | 90           |
-------------------------------------------------------------------------------------------------------


--------------------------------------------------
Script finished at: Mon Apr  7 14:39:11 UTC 2025
--------------------------------------------------

Done!
```
