*** Settings ***
Documentation	Test CephFS functions
#Suite Setup		Preflight
#Suite Teardown	Teardown
Test Setup		Check If CephFS Is Mounted

Library			OperatingSystem
Library         Process
Library			SSHLibrary
#Library			../framework/utils.py
#Resource		../framework/utils.robot
Variables		../properties/cephfs_props.py

*** Variables ***
${CONTENT}		This is a cephfs test.\n
${USER}			orchard
${SSHKEY}		/home/orchard/.ssh/id_rsa

*** Test Cases ***
MON HA
	[Documentation]		Validates cephfs is okay after one of mons is down:\n
	...		Create a directory and a file and read a file in cephfs.\n
	...		Stop ceph-mon@mon1 service in mon1.\n
	...		Check ceph health status.\n
	...		Create a directory and a file and read a file in cephfs.\n
	...		Start ceph-mon service in mon1.\n
	...		Check ceph health status.\n
	${mtpoint} =	Get CephFS Mountpoint
	Disk IO On CephFS		${mtpoint}

	Login And Run Command On Remote System	mon1	${USER}		${SSHKEY}
	...		sudo systemctl stop ceph-mon@mon1
	Wait Until Keyword Succeeds		30s		5s		Ceph Health		WARN

	${result} =		Run Process		sudo	ceph	health	timeout=5s
	Run Keyword If	${result.rc} == 0	Log		${result.stdout}
	Run Keyword If	${result.rc} == 0	Disk IO On CephFS		${mtpoint}

	Login And Run Command On Remote System	mon1	${USER}		${SSHKEY}
	...		sudo systemctl start ceph-mon@mon1
	Wait Until Keyword Succeeds		30s		5s		Ceph Health		OK

	${result} =		Run Process		sudo	ceph	health	timeout=5s
	Run Keyword If	${result.rc} == 0	Log		${result.stdout}
	Run Keyword If	${result.rc} == 0	Disk IO On CephFS		${mtpoint}

OSD Replication Resilience
	[Documentation]		Validates cephfs io is okay after osd1/2 is down:
	...		Run random file generator script in background.
	...		Shutdown osd1.
	...		Validate the script writes files in cephfs successfully.
	...		Check ceph health status.
	...		Shutdown osd2.
	...		Validate the script writes files in cephfs successfully.
	...		Check ceph health status.
	...		Stop random file generator script.
	Create File		foo.txt		${CONTENT}

OSD Scale Up
	[Documentation]		Validate objects are rebalanced when osd4 is added.
	...		Add osd4 into the cluster.
	...		Add osd4 into the cluster.
	Log		OSD scale up test	console=yes

OSD Scale Down
	[Documentation]		Validate objects are rebalanced when osd4 is down.
	...		Shutdown osd4.
	Log		OSD scale down test		console=yes

MDS HA
	[Documentation]		Validate mds2 becomes active if mds1 is down.
	...		Shutdown mds1.
	Log		MDS HA test		console=yes


*** Keywords ***
Check If CephFS Is Mounted
	${out} =	Run 	mount |grep -c ceph-fuse
	Should Be Equal As Integers		${out}		1

Get CephFS Mountpoint
	${out} =	Run		mount |grep ceph-fuse |cut -d' ' -f3
	[Return]	${out}
	
Run Random File Generator
    [Arguments]     @{args}
    Start Process   /home/orchard/rand_dir_file_gen.sh      @{args} stdout=${OUTPUTDIR}/rand_dir_file_gen.log       shell=True

Login And Run Command On Remote System
	[Arguments]		${host}		${user}		${key}		${cmd}
	[Documentation]	Executes a command on remote host and returns output.
	Open Connection	${host}
	Login With Public Key		${user}		${key}
	${output} =		Execute Command		${cmd}
	Close Connection
	[Return]	${output}

Disk IO On CephFS
	[Arguments]		${mtpoint}
	[Documentation]	Test disk io on ${mtpoint}.\n
	...		Create a directory foo.\n
	...		Create a file foo.txt.\n
	...		Read a file foo.txt.\n
	...		Delete a directory and a file.
	Create Directory	${mtpoint}/foo	
	OperatingSystem.Directory Should Exist		${mtpoint}/foo
	Create File		${mtpoint}/foo.txt		${CONTENT}
	OperatingSystem.File Should Exist	${mtpoint}/foo.txt
	${output} =	OperatingSystem.Get File		${mtpoint}/foo.txt
	Should Be Equal		${output}		${CONTENT}
	OperatingSystem.Remove File		${mtpoint}/foo.txt
	OperatingSystem.File Should Not Exist	${mtpoint}/foo.txt
	OperatingSystem.Remove Directory	${mtpoint}/foo
	OperatingSystem.Directory Should Not Exist	${mtpoint}/foo

Ceph Health
    [Documentation]		Check ceph health status is OK or WARN.
	[Arguments]		${status}
    ${result} =     Run Process     sudo    ceph    health  timeout=5s
    Should Contain	${result.stdout}	HEALTH_${status}
