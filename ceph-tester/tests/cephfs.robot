*** Settings ***
Documentation	Test CephFS functions
#Suite Setup		Preflight
#Suite Teardown	Teardown
Test Setup		Check If CephFS Is Mounted

Library			OperatingSystem
Library         Process
Library			SSHLibrary
#Library			../framework/utils.py
Resource		../framework/utils.robot
Variables		../properties/ceph_props.py

*** Variables ***
${CONTENT}		This is a cephfs test.\n

*** Test Cases ***
My Test
	[Documentation]		My Test\n
	[Tags]	mytest
	FOR		${host}	IN	@{OSDS}
		Log To Console	${host} ${OSDS}[${host}]
	END
	${monhost_to_down} =	Select Mon to Down
	Log		The mon host to down is ${monhost_to_down}.		console=True

MON HA
	[Documentation]		Validates cephfs is okay after one of mons is down:\n
	...		Create a directory and a file and read a file in cephfs.\n
	...		Select one of mon hosts to shutdown.\n
	...		Stop ceph-mon service in selected mon host.\n
	...		Check ceph health status.\n
	...		Create a directory and a file and read a file in cephfs.\n
	...		Start ceph-mon service in selected mon host.\n
	...		Check ceph health status.\n
	[Tags]	mon-ha
	${mtpoint} =	Get CephFS Mountpoint
	Disk IO On CephFS		${mtpoint}

	${mon2down} =	Select Mon to Down
	Log 	The mon host to down is ${mon2down}	console=True

	${out} =	Login And Run Command On Remote System	${mon2down}
	...		${USER}		${SSHKEY}
	...		sudo systemctl stop ceph-mon@${mon2down}
	Log 	${out}	console=True
	Wait Until Keyword Succeeds		30s		5s		Ceph Health		WARN

	${result} =		Run Process		sudo	ceph	health	timeout=5s
	Run Keyword If	${result.rc} == 0	
	...		Log		${result.stdout}	console=True
	Run Keyword If	${result.rc} == 0	Disk IO On CephFS		${mtpoint}

	${out} =	Login And Run Command On Remote System	${mon2down}
	...		${USER}		${SSHKEY}
	...		sudo systemctl start ceph-mon@${mon2down}
	Log To Console	${out}
	Wait Until Keyword Succeeds		30s		5s		Ceph Health		OK

	${result} =		Run Process		sudo	ceph	health	timeout=5s
	Run Keyword If	${result.rc} == 0	
	...		Log		${result.stdout}	console=True
	Run Keyword If	${result.rc} == 0	Disk IO On CephFS		${mtpoint}

OSD Replication Resilience
	[Documentation]		Validates cephfs io is okay after osd1/2 is down:\n
	...		Create a directory and a file and read a file in cephfs.\n
	...		Stop ceph-osd@{0,1,2,3} service in osd1.\n
	...		Check ceph health status.\n
	...		Create a directory and a file and read a file in cephfs.\n
	...		Stop ceph-osd@{4,5,6,7} service in osd2.\n
	...		Check ceph health status.\n
	...		Create a directory and a file and read a file in cephfs.\n
	...		Start ceph-osd@{0,1,2,3} service in osd1.\n
	...		Check ceph health status.\n
	...		Start ceph-osd@{4,5,6,7} service in osd2.\n
	...		Check ceph health status.\n
	[Tags]	osd
	${mtpoint} =	Get CephFS Mountpoint
	Disk IO On CephFS		${mtpoint}
	${out} =	Login And Run Command On Remote System	mon1
	...		${USER}		${SSHKEY}
	...		sudo systemctl stop ceph-mon@mon1
	Log To Console	${out}
	Wait Until Keyword Succeeds		30s		5s		Ceph Health		WARN

	No Operation


OSD Scale Up
	[Documentation]		Validate objects are rebalanced when osd4 is added.
	...		Add osd4 into the cluster.
	...		Check objects are moving to osd4 osds.
	[Tags]	osd234
	${out} =	Login And Run Command On Remote System	${OSDS}[0]
	...		${USER}		${SSHKEY}
	...		sudo systemctl status ceph-mon@mon1
	Log To Console		${out}
	No Operation

OSD Scale Down
	[Documentation]		Validate objects are rebalanced when osd4 is down.
	...		Shutdown osd4.
	[Tags]	osd
	No Operation

MDS HA
	[Documentation]		Validate mds2 becomes active if mds1 is down.
	...		Shutdown mds1.
	[Tags]	mds
	No Operation


*** Keywords ***
Select Mon To Down
	[Documentation]	Select one of mon hosts to down
	${len} =	Get Length	${MON_HOSTS}
	Should Be True	${len} > 1	The number of mon hosts should be at least 3.
	${GOT} =	Evaluate	random.choice($MON_HOSTS)		modules=random
	[Return]	${GOT}

Check If CephFS Is Mounted
	${out} =	Run 	mount |grep -c ceph-fuse
	Should Be Equal As Integers		${out}		1

Get CephFS Mountpoint
	${out} =	Run		mount |grep ceph-fuse |cut -d' ' -f3
	[Return]	${out}
	
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

