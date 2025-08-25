/**
 * MFRC522.h - Header file for MFRC522 RFID reader module for Microchip Studio (C)
 */

 #ifndef MFRC522_H
 #define MFRC522_H
 
 #include <avr/io.h>
 #include <stdbool.h>
 
 // MFRC522 Command set
 #define PCD_IDLE              0x00
 #define PCD_AUTHENT           0x0E
 #define PCD_RECEIVE           0x08
 #define PCD_TRANSMIT          0x04
 #define PCD_TRANSCEIVE        0x0C
 #define PCD_RESET             0x0F
 #define PCD_CALCCRC           0x03
 
 #define PICC_REQIDL           0x26
 #define PICC_ANTICOLL         0x93
 #define PICC_SElECTTAG        0x93
 #define PICC_HALT             0x50
 
 // MFRC522 Register definitions (partial)
 #define CommandReg            0x01
 #define CommIEnReg            0x02
 #define DivIEnReg             0x03
 #define CommIrqReg            0x04
 #define FIFOLevelReg          0x0A
 #define FIFODataReg           0x09
 #define BitFramingReg         0x0D
 #define ModeReg               0x11
 #define TxControlReg          0x14
 #define VersionReg            0x37
 
 // Function Prototypes
 void MFRC522_Init(uint8_t ss_pin, uint8_t rst_pin);
 bool MFRC522_IsCardPresent(void);
 bool MFRC522_ReadCardSerial(void);
 void MFRC522_Halt(void);
 
 #endif
 