import asyncio

from bleak import BleakScanner, BleakClient
from bleak.backends.scanner import AdvertisementData
from bleak.backends.device import BLEDevice

UART_SERVICE_UUID = "48093801-1a48-11e9-ab14-d663bd873d93"
UART_RX_CHAR_UUID = "48090002-1a48-11e9-ab14-d663bd873d93"
UART_TX_CHAR_UUID = "48090001-1a48-11e9-ab14-d663bd873d93"

MAC_ADDR = ""
DEVICE_NAME = "EDIFIER BLE"

ESCAPE_LIST = [0x07, 0xCD, 0xCE, 0xCF, 0xD1, 0xD2, 0xD3]
# factory reset, disconnect, shutdown, re-pair, timer [d1-d3]

UTF8_LIST_OUT = [0xCA]
# rename BT

UTF8_LIST_IN = [0x01, 0x02, 0xc9]
# title, author, BT name

DEC_LIST_IN = [0x05, 0x06, 0xd0]
# prompt vol (get), prompt vol (set), battery (%)

# All BLE devices have MTU of at least 23. Subtracting 3 bytes overhead, we can
# safely send 20 bytes at a time to any device supporting this service.
UART_SAFE_SIZE = 20

temp_data = bytearray()


async def uart_terminal():
    """This is a simple "terminal" program that uses the Nordic Semiconductor
    (nRF) UART service. It reads from stdin and sends each line of data to the
    remote device. Any data received from the device is printed to stdout.
    """

    def match_name(device: BLEDevice, adv: AdvertisementData):
        return device.name == DEVICE_NAME

    if MAC_ADDR:
        device = await BleakScanner.find_device_by_address(MAC_ADDR)
    else:
        device = await BleakScanner.find_device_by_filter(match_name)

    def handle_disconnect(_: BleakClient):
        print("Device was disconnected, goodbye.")
        # cancelling all tasks effectively ends the program
        for task in asyncio.all_tasks():
            task.cancel()

    def print_parsed_data(data: bytearray):
        print('dir:', hex(data[0]))
        print('len:', data[1] - 1)
        print('cmd:', hex(data[2]))
        if data[2] in UTF8_LIST_IN:
            print('str:', data[3:-2].decode('utf-8', errors='ignore'))
        if data[2] in DEC_LIST_IN:
            print('dec:', data[3])
        print('dat:', data[3:-2].hex())
        print('crc:', hex(cut_crc(data)))
        print()

    def handle_rx(_: int, data: bytearray):
        global temp_data
        data = temp_data + data
        if calc_crc(data) == cut_crc(data) and data[1] + 4 == len(data):
            temp_data = bytearray()
            print_parsed_data(data)
        else:
            temp_data = data

    async with BleakClient(device, disconnected_callback=handle_disconnect) as client:
        await client.start_notify(UART_TX_CHAR_UUID, handle_rx)

        print("Connected to", client.address)
        loop = asyncio.get_running_loop()

        while True:
            try:
                data = await loop.run_in_executor(None, input)
                if not data:
                    continue

                if "q" in data:
                    break

                elif "s" in data:
                    c = int(input("cmd: "), 16)
                    for i in range(256):
                        b = bytearray([i % 256])
                        data_hex = cmd_builder(c, b)
                        await client.write_gatt_char(UART_RX_CHAR_UUID, data_hex)
                        print("sent:", data_hex.hex())
                        await asyncio.sleep(0.1)
                    continue

                elif "w" in data:
                    b = bytearray.fromhex(input("hex: "))
                    for c in range(256):  # known cmd list
                        if c in ESCAPE_LIST:
                            continue
                        data_hex = cmd_builder(c, b)
                        await client.write_gatt_char(UART_RX_CHAR_UUID, data_hex)
                        print("sent:", data_hex.hex())
                        await asyncio.sleep(0.1)
                    continue

                elif "r" in data:
                    c = int(input("cmd: "), 16)
                    if c in UTF8_LIST_OUT:
                        d = bytearray(input("utf8: "), encoding="utf8")
                    else:
                        d = bytearray.fromhex(input("data: "))
                    data_hex = cmd_builder(c, d)
                else:
                    if len(data) < 8:
                        continue
                    data_hex = bytearray.fromhex(data)

                if calc_crc(data_hex) == cut_crc(data_hex):
                    print("sending:", data_hex.hex())
                    if len(data_hex) <= UART_SAFE_SIZE:
                        await client.write_gatt_char(UART_RX_CHAR_UUID, data_hex)
                    else:
                        while data_hex:
                            await client.write_gatt_char(UART_RX_CHAR_UUID, data_hex[:UART_SAFE_SIZE])
                            await asyncio.sleep(0.05)
                            data_hex = data_hex[UART_SAFE_SIZE:]
                    print()

                else:
                    print("wrong crc")

            except ValueError:
                print("input is not in hex format")
                continue


def cut_crc(arr):
    arr = arr[-2:]
    return (arr[0] << 8) + arr[1]


def calc_crc(arr):
    return sum(arr[:-2]) + 0x2019


def cmd_builder(cmd: int, data: bytearray) -> bytearray:
    res = bytearray(len(data) + 5)
    res[0] = 0xaa
    res[1] = len(data) + 1
    res[2] = cmd % 256
    for i in range(len(data)):
        res[i + 3] = data[i]
    crc = calc_crc(res)
    res[-2] = (crc >> 8) % 256
    res[-1] = crc % 256
    return res


if __name__ == "__main__":
    try:
        asyncio.run(uart_terminal())
    except asyncio.CancelledError:
        # task is cancelled on disconnect, so we ignore this error
        pass
