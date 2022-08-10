# Edifier Bluetooth/BLE control protocol analysis

> Disclaimer: Using this software may cause damage to your device! Use at your own risk!

> All trademarks, logos and brand names are the property of their respective owners. All
> company, product and service names used in this repo are for identification purposes only.

---

## Packet structure

Each packet, incoming or outgoing, starts with an "INIT" byte and ends with a 2-byte CRC.
Inside the packet are a length byte, a command byte, and a data array (optional).

*ALL DATA IN HEXADECIMAL REPRESENTATION*

| INIT `1 byte` |  LEN `1 byte`   | CMD `1 byte` | DATA `any len` |      CRC `2 byte`       |
|:-------------:|:---------------:|:------------:|:--------------:|:-----------------------:|
|   AA/BB/CC    | `len(DATA) + 1` |     ANY      |   BYTE ARRAY   | `sum(PAYLOAD) + 0x2019` |

+ INIT byte value
    + AA - data from device to headphones **[REQUEST]**
    + BB - data from headphones to device **[RESPONSE]**
    + CC - data from headphones to device (only in few cases with confirmation data)
    + *other cases unknown*
+ LEN byte represents length of CMD and DATA sequence (or just `len(DATA) + 1` for simplicity)
+ [CMD byte](#cmd-list) can take any value
+ DATA can be empty, UTF-8 string or CMD specific
+ CRC is all bytes sum plus *magic* value `0x2019` [`INIT + LEN + CMD + sum(DATA) + 0x2019`]

> **[UNTESTED, RARE]** Some devices may use `0xEC` byte instead of LEN byte on some CMD

---

## CMD list

> Some commands may not be available on some devices, cause glitches, etc.

> Commands are obtained using live Wireshark capture and triggering specific functions of app in realtime

### W820NB commands

| name                                      | CMD |    request     |                  response                   |
|-------------------------------------------|:---:|:--------------:|:-------------------------------------------:|
| [track](#track) title                     | 01  |                |                    UTF-8                    |
| [track](#track) author                    | 02  |                |                    UTF-8                    |
| [prompt volume](#prompt-volume) get       | 05  |    {empty}     |                   {00-0f}                   |
| [prompt volume](#prompt-volume) set       | 06  |    {00-0f}     |                   {00-0f}                   |
| **FACTORY RESET**                         | 07  |    {empty}     |                    {01}                     |
| [game mode](#game-mode) get               | 08  |    {empty}     |                   {00-01}                   |
| [game mode](#game-mode) set               | 09  |    {00-01}     |                   {00-01}                   |
| **UNKNOWN**                               | a0  |    {empty}     |                  {00}{01}                   |
| [ANC/AMB/OFF](#anc-ambient-mode) set      | c1  | {mode}`{vol}`  |                 {mode}{vol}                 |
| [send button](#send-button)               | c2  |     {code}     |                                             |
| [playback state](#playback-state) get     | c3  |    {empty}     |                 {03,0d,??}                  |
| firmware version get                      | c6  |    {empty}     |                {xx}{yy}{zz}                 |
| MAC address get                           | c8  |    {empty}     |                  [mac hex]                  |
| [device name](#bluetooth-device-name) get | c9  |    {empty}     |                    UTF-8                    |
| [device name](#bluetooth-device-name) set | ca  |     UTF-8      |                  `CC` {01}                  |
| [ANC/AMB/OFF](#anc-ambient-mode) get      | cc  |    {empty}     |                 {mode}{vol}                 |
| **DISCONNECT**                            | cd  |    {empty}     |                                             |
| **POWER OFF**                             | ce  |    {empty}     |                                             |
| **RE-PAIR**                               | cf  |    {empty}     |                                             |
| battery get                               | d0  |    {empty}     |                 {xx} `in %`                 |
| [shutdown timer](#shutdown-timer) set     | d1  | {xx}{yy} `min` |                  `CC` {01}                  |
| [shutdown timer](#shutdown-timer) disable | d2  |    {empty}     |                  `CC` {01}                  |
| [shutdown timer](#shutdown-timer) get     | d3  |    {empty}     |         {xx}{yy} `min` / {00} `off`         |
| [game mode](#game-mode) toggled by app    | d5  |                |                    {01}                     |
| model fingerprint                         | d8  |    {empty}     | [030101010101010100<br/>000101000000000070] |
| [**UNKNOWN**](#prompt-volume) get         | f9  |    {empty}     |                    {xx}                     |
| [**UNKNOWN**](#prompt-volume) set         | fa  |      {xx}      |                    {xx}                     |

#### Track
> track info from AVRCP, read-only, glitch sometimes
#### Prompt volume
> represents voice comments volume, value 0-15
> cmd {f9-fa} implicitly linked with prompt volume
#### Game mode
> toggle low latency mode
> + 00 - off
> + 01 - on
#### ANC, Ambient mode
> mode:
> + 01 - disabled 
> + 02 - ANC
> + 03 - Ambient
> ambient volume {03-09} (optional for request)
> + 09 - +3
> + 06 - 0
> + 03 - -3
#### send button
> **Bluetooth only**
> code:
> + 00 - play
> + 01 - pause
> + 02 - vol+ `windows only ? emulate keyboard key`
> + 03 - vol- `windows only ? emulate keyboard key`
> + 04 - next track
> + 05 - prev track
#### playback state
> triggers on track change or query
> + 03 - pause
> + 0d - play
#### Bluetooth device name
> any UTF-8, byte array sequence, len 0-35.
#### Shutdown timer
> value in [u]int16
> + {d1} - take value in minutes, on 00 shutdowns immediately
> + {d3} - returns the selected value (len 2)
> + {d3} - timer disabled {00} (len 1)
