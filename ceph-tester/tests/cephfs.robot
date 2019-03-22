*** Settings ***
Documentation    Test CephFS functions
#Suite Setup        Preflight
#Suite Teardown    Teardown
Test Setup        Check If CephFS Is Mounted

Library            OperatingSystem
Library         Process
Library            SSHLibrary
#Library            ../framework/utils.py
Resource        ../framework/utils.robot
Variables        ../properties/ceph_props.py

*** Variables ***
${CONTENT}        This is a cephfs test.\n

*** Test Cases ***
My Test
    [Documentation]        My Test\n
    [Tags]    mytest
    ${active}    ${standby} =    Get MDS
    Log     ${active} ${standby}    console=True
    ${OSD_TOTAL}    ${OSD_DOWN_MAX} =    Select OSD To Down
    Log        The osds to down are ${OSD_DOWN_MAX}.        console=True
    ${cur} =      Set Variable    0
    FOR        ${host}    IN    @{OSDS}
        ${cur} =    Test Args  ${host}  
        ...     ${OSDS}[${host}]  ${cur}    ${OSD_DOWN_MAX}     stop
        Log     ${cur} ${OSD_DOWN_MAX}     console=True
        Exit For Loop If    ${cur} == ${OSD_DOWN_MAX}
    END
    Log     \# of down osds is ${cur} / ${OSD_TOTAL}.  console=True

MON HA
    [Documentation]        Validates cephfs is okay after one of mons is down:\n
    ...        Create a directory and a file and read a file in cephfs.\n
    ...        Select one of mon hosts to shutdown.\n
    ...        Stop ceph-mon service in selected mon host.\n
    ...        Check ceph health status.\n
    ...        Create a directory and a file and read a file in cephfs.\n
    ...        Start ceph-mon service in selected mon host.\n
    ...        Check ceph health status.\n
    [Tags]    cephfs    mon-ha
    ${mtpoint} =    Get CephFS Mountpoint
    Disk IO On CephFS        ${mtpoint}

    ${mon_down} =    Select Mon to Down
    Log     The mon host to down is ${mon_down}    console=True

    ${out} =    Login And Run Command On Remote System    ${mon_down}
    ...        ${USER}        ${SSHKEY}
    ...        sudo systemctl stop ceph-mon@${mon_down}
    Log     ${out}    console=True
    Wait Until Keyword Succeeds        30s        5s        Ceph Health        WARN

    ${result} =        Run Process        sudo    ceph    health    timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True
    Run Keyword If    ${result.rc} == 0    Disk IO On CephFS        ${mtpoint}

    ${out} =    Login And Run Command On Remote System    ${mon_down}
    ...        ${USER}        ${SSHKEY}
    ...        sudo systemctl start ceph-mon@${mon_down}
    Log     ${out}      console=True
    Wait Until Keyword Succeeds   30s   5s   Ceph Health        OK

    ${result} =        Run Process        sudo    ceph    health    timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True
    Run Keyword If    ${result.rc} == 0    Disk IO On CephFS        ${mtpoint}

OSD Replication Resilience
    [Documentation]        Validates cephfs io is okay when osds are down.\n
    ...        Create a directory and a file and read a file in cephfs.\n
    ...        Stop one less than half of osds services.\n
    ...        Check if ceph health status should be WARN.\n
    ...        Create a directory and a file and read a file in cephfs.\n
    ...        Show the output of ceph osd df.\n
    ...        Start ceph-osd services.\n
    ...        Check ceph health status.\n
    ...        Create a directory and a file and read a file in cephfs.\n
    ...        Show the output of ceph osd df.\n
    [Tags]    cephfs    osd-ha
    ${mtpoint} =    Get CephFS Mountpoint
    Disk IO On CephFS        ${mtpoint}

    ${total}    ${max} =    Select OSD To Down
    Log     The number of osds to down is ${max} of ${total}.    console=True

    ${cur} =    Set Variable    0
    FOR        ${host}    IN    @{OSDS}
        ${cur} =    OSD Services  ${host}   ${OSDS}[${host}]
        ...     ${cur}      ${max}  stop
        Exit For Loop If    ${cur} == ${max}
    END
    Wait Until Keyword Succeeds    30s    5s   Ceph Health   WARN

    ${result} =       Run Process   sudo    ceph    health    timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True
    Run Keyword If    ${result.rc} == 0    Disk IO On CephFS   ${mtpoint}

    ${result} =   Run Process   sudo   ceph   osd   stat      timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True
    ${result} =   Run Process   sudo   ceph   osd   df      timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True

    Log     Start all OSD services.     console=True
    ${cur} =    Set Variable    0
    FOR        ${host}    IN    @{OSDS}
        ${cur} =    OSD Services   ${host}  ${OSDS}[${host}]
        ...     ${cur}  ${total}  start
    END
    Wait Until Keyword Succeeds    30s    5s   Ceph Health   OK

    ${result} =        Run Process        sudo    ceph    health    timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True
    Run Keyword If    ${result.rc} == 0    Disk IO On CephFS   ${mtpoint}

    ${result} =   Run Process   sudo   ceph   osd   stat      timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True
    ${result} =   Run Process   sudo   ceph   osd   df      timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True

MDS HA
    [Documentation]        Validate MDS HA.
    ...     Get active and standby mds hosts.
    ...     Create a directory and a file and read a file in cephfs.\n
    ...     Stop the active mds service.
    ...     Check if ceph health status should be WARN.\n
    ...     Create a directory and a file and read a file in cephfs.\n
    ...     Show the output of ceph mds stat.\n
    ...     Start the stopped mds service.
    ...     Create a directory and a file and read a file in cephfs.\n
    ...     Show the output of ceph mds stat.\n
    [Tags]    cephfs    mds-ha
    ${mtpoint} =    Get CephFS Mountpoint
    Disk IO On CephFS        ${mtpoint}

    ${active}    ${standby} =    Get MDS
    Log     active mds: ${active}, standby mds: ${standby}    console=True

    ${out} =    Login And Run Command On Remote System    ${active}
    ...        ${USER}        ${SSHKEY}
    ...        sudo systemctl stop ceph-mds@${active}
    Wait Until Keyword Succeeds    30s    5s   Ceph Health   WARN

    ${result} =       Run Process   sudo    ceph    health    timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True
    Run Keyword If    ${result.rc} == 0    Disk IO On CephFS   ${mtpoint}

    ${result} =   Run Process   sudo   ceph   mds   stat      timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True

    ${out} =    Login And Run Command On Remote System    ${active}
    ...        ${USER}        ${SSHKEY}
    ...        sudo systemctl start ceph-mds@${active}
    Wait Until Keyword Succeeds    30s    5s   Ceph Health   OK

    ${result} =       Run Process   sudo    ceph    health    timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True
    Run Keyword If    ${result.rc} == 0    Disk IO On CephFS   ${mtpoint}

    ${result} =   Run Process   sudo   ceph   mds   stat      timeout=5s
    Run Keyword If    ${result.rc} == 0    
    ...        Log        ${result.stdout}    console=True
    
*** Keywords ***
Test Args
    [Arguments]     ${host}    ${osd_list}    ${cur}    ${max}     ${action}
    Log     ${host} @{osd_list}     console=True
    FOR     ${index}   IN   @{osd_list}
        ${cur} =   Evaluate    ${cur} + 1
        Log     cur is ${cur}.    console=True
        Exit For Loop If    ${cur} == ${max}
    END
    [Return]    ${cur}

Get MDS
    [Documentation]     Get active/standby mds.
    ${standby} =    Run      sudo ceph mds stat -f json|python -c 'import sys, json;print(json.load(sys.stdin)["fsmap"]["standbys"][0]["name"])'
    Should Contain      ${MDS_HOSTS}    ${standby}
    ${active} =    Evaluate    list(set(${MDS_HOSTS})-set(["${standby}"]))[0]
    [Return]    ${active}   ${standby}
    
OSD Services
    [Documentation]     Stop/Start OSD Services on the host.
    [Arguments]     ${host}     ${osd_list}   ${cur}    ${max}    ${action}
    FOR     ${index}   IN   @{osd_list}
        Log     ${index} ${cur} ${max}    console=True
        Login And Run Command On Remote System    ${host}
        ...        ${USER}        ${SSHKEY}
        ...        sudo systemctl ${action} ceph-osd@${index}
        ${cur} =   Evaluate    ${cur} + 1
        Exit For Loop If    ${cur} == ${max}
    END
    [Return]    ${cur}

Select OSD To Down
    [Documentation]     Select one less than half number of osds.
    ${total} =    Set Variable    0
    FOR        ${host}    IN    @{OSDS}
        ${tmpnum} =    Get Length    ${OSDS}[${host}]
        ${total} =    Evaluate    ${total} + ${tmpnum}
    END
    ${num} =    Evaluate    int(${total} / 2 - 1)
    Should Be True      ${num} > 1  The number to down should be at leat 1.
    [Return]    ${total}    ${num}

Select Mon To Down
    [Documentation]    Select one of mon hosts to down
    ${len} =    Get Length    ${MON_HOSTS}
    Should Be True    ${len} > 1    The number of mon hosts should be at least 3.
    ${GOT} =    Evaluate    random.choice($MON_HOSTS)        modules=random
    [Return]    ${GOT}

Check If CephFS Is Mounted
    ${out} =    Run     mount |grep -c ceph-fuse
    Should Be Equal As Integers        ${out}        1

Get CephFS Mountpoint
    ${out} =    Run        mount |grep ceph-fuse |cut -d' ' -f3
    [Return]    ${out}
    
Disk IO On CephFS
    [Arguments]        ${mtpoint}
    [Documentation]    Test disk io on ${mtpoint}.\n
    ...        Create a directory foo.\n
    ...        Create a file foo.txt.\n
    ...        Read a file foo.txt.\n
    ...        Delete a directory and a file.
    Create Directory    ${mtpoint}/foo    
    OperatingSystem.Directory Should Exist        ${mtpoint}/foo
    Create File        ${mtpoint}/foo.txt        ${CONTENT}
    OperatingSystem.File Should Exist    ${mtpoint}/foo.txt
    ${output} =    OperatingSystem.Get File        ${mtpoint}/foo.txt
    Should Be Equal        ${output}        ${CONTENT}
    OperatingSystem.Remove File        ${mtpoint}/foo.txt
    OperatingSystem.File Should Not Exist    ${mtpoint}/foo.txt
    OperatingSystem.Remove Directory    ${mtpoint}/foo
    OperatingSystem.Directory Should Not Exist    ${mtpoint}/foo
