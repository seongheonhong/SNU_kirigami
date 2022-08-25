"""
Seongheon Hong, 2021
This program is for data transmission between developed nrf52810 glove module and Python
This uses the Nordic Uart Service and should work concurrently with other BLE services such as HID
On the python side, the Bluetooth Low Energy platform Agnostic Klient for Python (Bleak) project
is used for Cross Platform Support.
Tested with windows 10.
"""

import platform, logging, asyncio, serial, time, struct
import numpy as np
import pandas as pd
from bleak import BleakClient
from bleak import BleakClient
from bleak import _logger as logger
from bleak.uuids import uuid16_dict


SECMAC = "E8:28:5C:89:A2:BE"
SECMAC2 = "E5:81:AF:EC:55:8E"
UART_RX_UUID = "013d1401-ea29-44e0-b349-72c42795b83d" #Nordic NUS characteristic for RX
SIZEMAX = 11000

PASSFLAGCOUNT = 20
CHCOUNT = 4
CONTCOUNT = 4
THRESHOLD = -40

dataFlag = False #global flag to check for new data
clearFlag = False
global count, timecap, gradflag, startval, startcount, passflag, chbuffer, gain, writeval, pcrit, ncrit
timecap = 0
count = np.uint16(10)
startcount = [0,0,0,0]
startval = [0,0,0,0]
passflag = [0,0,0,0]
gradflag = [0,0,0,0]
writeval = [1,1,1,1]
pcrit = np.int8([50, 60, 60, 60])
ncrit = -0.8 * pcrit
#ncrit = [-50, -75, -75, -75]
chbuffer = np.zeros((CHCOUNT,SIZEMAX), dtype='int16')
gain = [1.6, 1.3, 1.1, 1.4]

#############################################
flushed = [True, True, True, True];
tempbuf = [0, 0, 0, 0];
signdata = np.zeros((CHCOUNT,SIZEMAX), dtype='int16')
signdata2 = np.zeros((CHCOUNT,SIZEMAX), dtype='int16')
graddata = np.zeros((CHCOUNT,SIZEMAX), dtype='int16')
stcbuf = np.zeros((CHCOUNT,SIZEMAX), dtype='int16')
endbuf = np.zeros((CHCOUNT,SIZEMAX), dtype='int16')

def notification_handler(sender, data):
    
    global count, timecap, gradflag, startval, startcount, passflag, dataFlag, chbuffer, gain, writeval, pcrit, ncrit \
        , flushed, tempbuf, signdata, signdata2, graddata, stcbuf, endbuf, clearFlag
    
    count = np.uint16(count + 1)
    
    chbuffer[0, count] = 3000-np.frombuffer(data[6:8],dtype=np.int16)[0]
    chbuffer[1, count] = 3000-np.frombuffer(data[0:2],dtype=np.int16)[0]
    chbuffer[2, count] = 3000-np.frombuffer(data[2:4],dtype=np.int16)[0]
    chbuffer[3, count] = 3000-np.frombuffer(data[4:6],dtype=np.int16)[0]
    plotval = -np.int16(chbuffer[:,count]//32-70);        
    graddata[:,count] = (chbuffer[:,count] - chbuffer[:,np.uint16(count - 1)])
    writeval = [1,1,1,1]
    writeflag = False

    for i in range(0, CHCOUNT):
        if chbuffer[i, count] - chbuffer[i, count-CONTCOUNT] < THRESHOLD:
            signdata[i, count - CONTCOUNT : count+1] = np.ones((1,CONTCOUNT + 1))
            if signdata[i, count-CONTCOUNT -1] < 1:
                stcbuf[i, count-CONTCOUNT] = 1;
                tempbuf[i] = count-CONTCOUNT;
                flushed[i] = False;
        elif signdata[i,count - 1] > 0 and flushed[i] == False:
            endbuf[i,count] = np.max(chbuffer[i, tempbuf[i]:count+1]) - np.min(chbuffer[i, tempbuf[i]:count+1]);
            flushed[i] = True;
            writeflag = True;
            if endbuf[i,count] > 200:
                writeval[i] = np.uint8(np.min([gain[i] * np.absolute(endbuf[i, count]) / 10, 127]))            
        plotval[i] = i*64 + plotval[i]
    if writeflag:
        ser.write(bytes(writeval))
        print("COUNT : {0} - [{1}\t{2}\t{3}\t{4}]".format(count, chbuffer[0,count],chbuffer[1,count],chbuffer[2,count],chbuffer[3,count]))
        print(writeval)

    ser2.write(bytes(plotval))

    if count % 100 == 0 :
        print('--------------')
        timediff = (time.time()-timecap)*1000
        print(timediff)
        timecap = time.time()        
    dataFlag = True

    while ser.inWaiting():
        ser.read()
        clearFlag = True

def notification_handler2(sender, data):
    """Simple notification handler which prints the data received."""
    global count, timecap, gradflag, startval, startcount, passflag, dataFlag, chbuffer, gain, writeval, pcrit, ncrit
    count = np.uint16(count + 1)
    
    chbuffer[0, count] = np.frombuffer(data[6:8],dtype=np.int16)[0]
    chbuffer[1, count] = np.frombuffer(data[0:2],dtype=np.int16)[0]
    chbuffer[2, count] = np.frombuffer(data[2:4],dtype=np.int16)[0]
    chbuffer[3, count] = np.frombuffer(data[4:6],dtype=np.int16)[0]
    
    grad = (chbuffer[:,count] - chbuffer[:,np.uint16(count - 1)])
    writeval = [1,1,1,1]
    writeflag = False
    for i in range(0, CHCOUNT):
        if grad[i] < ncrit[i] and gradflag[i] != -1:
            if gradflag[i] == 1:
                if startcount[i] < count:
                    valmax = np.max(chbuffer[i, startcount[i]:count])
                else:
                    valmax = np.max([chbuffer[i, startcount[i]:SIZEMAX], chbuffer[i, 0:count]])
                writeval[i] = np.uint8(np.min([np.absolute(gain[i] * (valmax-startval[i])/np.uint16(count-startcount[i])),127]))
                if passflag[i] == 0:
                    #ser.write(writeval[i].tobytes())
                    writeflag = True
                    passflag[i] = PASSFLAGCOUNT
                if writeval[i] > 127 :
                    raise ValueError('OVER 127')
                print("CH{5} : {0}\t{1}\t{2}\t{3}\t{4}".format(valmax, startval[i], count, startcount[i], writeval[i], i+1))
                #print(writeval[i])
                #time.sleep(0.001)
                gradflag[i] = 0
            #ser.write((np.uint8(0)).tobytes())      
            writeval[i] = 0          
            #time.sleep(0.001)
            gradflag[i] = -1
        elif grad[i] > pcrit[i]:
            if gradflag[i] != 1:
                startval[i] = chbuffer[i, np.uint16(count)]
                startcount[i] = count
            gradflag[i] = 1
        else:
            if gradflag[i] == 1:        
                writeval[i] = np.uint8(np.min([np.absolute(gain[i] * (chbuffer[i, count]-startval[i])/np.uint16(count-startcount[i])),127]))
                if passflag[i] == 0:
                    #ser.write(writeval[i].tobytes())
                    writeflag = True
                    #time.sleep(0.001)
                    passflag[i] = PASSFLAGCOUNT
                if writeval[i] > 127 :
                    raise ValueError('OVER 127')
                #time.sleep(0.001)
                #print(writeval[i])
                #print("CH{5} : {0}\t{1}\t{2}\t{3}\t{4}".format(chbuffer[i, count], startval[i], count, startcount[i], writeval[i], i+1))
                print(grad)
                #time.sleep(0.002)
                gradflag[i] = 0
        if passflag[i] > 0:
            passflag[i] = passflag[i] - 1
    if writeflag:
        ser.write(bytes(writeval))
        print("COUNT : {0} - [{1}\t{2}\t{3}\t{4}]".format(count, chbuffer[0,count],chbuffer[1,count],chbuffer[2,count],chbuffer[3,count]))
        print(writeval)
    ser2.write(bytes(np.int8(chbuffer[:,count]//32)))
    if count % 100 == 0 :
        print('--------------')
        timediff = (time.time()-timecap)*1000
        print(timediff)
        timecap = time.time()        
    dataFlag = True


async def run(address, loop):

    async with BleakClient(address, loop=loop) as client:
        global count, dataFlag, clearFlag
        #wait for BLE client to be connected
        #x = await client.is_connected()
        #print("Connected: {0}".format(x))
        #await client.stop_notify(UART_RX_UUID)
        #wait for data to be sent from client
        await client.start_notify(UART_RX_UUID, notification_handler)
        try:
            while True : 
                #give some time to do other tasks
                await asyncio.sleep(0.005)
                if clearFlag:
                    await client.write_gatt_char(UART_RX_UUID, b'a')
                    clearFlag = False
                #check if we received data
                if dataFlag :
                    if count > 10000:
                        await client.stop_notify(UART_RX_UUID)
                        raise ValueError('1000 COUNTS')
                    else:
                        dataFlag = False
                        #echo our received data back to the BLE device                
                        data = await client.read_gatt_char(UART_RX_UUID) 
                
        except Exception as e:
            print(e)
            print(client.is_connected)
            await client.disconnect()
            data = 0
            
            
        


if __name__ == "__main__":
    
    address = (
        SECMAC
    )
    ser = serial.Serial(port='COM2', baudrate=115200)
    ser2 = serial.Serial(port='COM4', baudrate=115200)
        
    loop = asyncio.get_event_loop()        
    loop.run_until_complete(run(address, loop))
    b2uf = np.transpose(chbuffer)
    df = pd.DataFrame(b2uf)
    df.to_excel('\\\\192.168.0.102\\hsh\\0. SNU 관련\\IDIM\\KOKO.xlsx', index=False)
