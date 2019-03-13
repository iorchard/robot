*** Settings ***
Documentation	Resource for various utilities
Library			OperatingSystem
Library         Process
Library			SSHLibrary


*** Keywords ***
Login And Run Command On Remote System
	[Arguments]		${host}		${user}		${key}		${cmd}
	[Documentation]	Executes a command on remote host and returns output.
	Open Connection	${host}
	Login With Public Key		${user}		${key}
	${output} =		Execute Command		${cmd}
	Close Connection
	[Return]	${output}

Ceph Health
    [Documentation]		Check ceph health status is OK or WARN.
	[Arguments]		${status}
    ${result} =     Run Process     sudo    ceph    health  timeout=5s
    Should Contain	${result.stdout}	HEALTH_${status}
