# SNU_kirigami

Software code repos. for the research on stretchable piezoelectric strain sensor with kirigami pattern.

## Matlab piezoelectric measurement simulator

#### Some results from this work was included in our presentation at International Conference on Advanced Electromaterials, Jeju, Korea, 2021

>Some researches miss the importance of measurement device.
>Because piezoelectric generators(energy harvestor, sensors, etc.) contain its own resistance and capacitance,
>measured voltage is highly affected by the total resistance and capacitance of measurement circuit.

>Generally, voltmeters with low-price, high sample rate, high resolution tend to have low internal impedance, making them far from ideal voltmeter.
>(e.g. NI-USB6009, Arduino UNO ADC, etc.)

>This simulator will show how voltage profile differs depending on measurement devices(or circuits) with different specs.
>You can compare results of two cases below:
  Case 1) R=144E3, C=350E-12: simulated NI-USB6009(Low price) DAQ and our sensor(simplified).
>>Case 2) R=1E15,  C=2350E-12: simulated keithley 6514(Excellent quality) electrometer and our sensor(simplified).
>>Case 3) R=100E6, C=2350E-12: simulated some mid-range voltmeters and our sensor.

>Then, you may find that case 2) shows higher and steady voltage-time profile than others.
