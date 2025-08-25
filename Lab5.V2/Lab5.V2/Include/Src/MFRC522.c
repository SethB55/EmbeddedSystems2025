/**
 * MFRC522.c - Implementation file for MFRC522 RFID reader module for Microchip Studio (C)
 */

 #include "MFRC522.h"
 #include <util/delay.h>
 
 static uint8_t _ss_pin;
 static uint8_t _rst_pin;
 
 void SPI_Write(uint8_t data) {
     SPDR = data;
     while (!(SPSR & (1 << SPIF)));
 }
 
 uint8_t SPI_Read(void) {
     SPI_Write(0x00);
     return SPDR;
 }
 
 void MFRC522_WriteRegister(uint8_t reg, uint8_t value) {
     PORTB &= ~(1 << _ss_pin);
     SPI_Write((reg << 1) & 0x7E);
     SPI_Write(value);
     PORTB |= (1 << _ss_pin);
 }
 
 uint8_t MFRC522_ReadRegister(uint8_t reg) {
     PORTB &= ~(1 << _ss_pin);
     SPI_Write(((reg << 1) & 0x7E) | 0x80);
     uint8_t value = SPI_Read();
     PORTB |= (1 << _ss_pin);
     return value;
 }
 
 void MFRC522_SetBitMask(uint8_t reg, uint8_t mask) {
     uint8_t tmp = MFRC522_ReadRegister(reg);
     MFRC522_WriteRegister(reg, tmp | mask);
 }
 
 void MFRC522_ClearBitMask(uint8_t reg, uint8_t mask) {
     uint8_t tmp = MFRC522_ReadRegister(reg);
     MFRC522_WriteRegister(reg, tmp & (~mask));
 }
 
 void MFRC522_Init(uint8_t ss_pin, uint8_t rst_pin) {
     _ss_pin = ss_pin;
     _rst_pin = rst_pin;
 
     DDRB |= (1 << _ss_pin);
     PORTB |= (1 << _ss_pin);
 
     DDRB |= (1 << _rst_pin);
     PORTB |= (1 << _rst_pin);
     _delay_ms(50);
     PORTB &= ~(1 << _rst_pin);
     _delay_ms(50);
     PORTB |= (1 << _rst_pin);
 
     MFRC522_WriteRegister(CommandReg, PCD_RESET);
     _delay_ms(50);
 
     MFRC522_WriteRegister(ModeReg, 0x3D);
     MFRC522_WriteRegister(TxControlReg, 0x83);
 }
 
 bool MFRC522_IsCardPresent(void) {
     MFRC522_WriteRegister(BitFramingReg, 0x07);
     MFRC522_WriteRegister(CommandReg, PCD_TRANSCEIVE);
     MFRC522_WriteRegister(FIFODataReg, PICC_REQIDL);
 
     MFRC522_SetBitMask(BitFramingReg, 0x80);
     _delay_ms(1);
 
     uint8_t irq = MFRC522_ReadRegister(CommIrqReg);
     return irq & 0x01 ? false : true;
 }
 
 bool MFRC522_ReadCardSerial(void) {
     MFRC522_WriteRegister(BitFramingReg, 0x00);
     MFRC522_WriteRegister(FIFODataReg, PICC_ANTICOLL);
     MFRC522_WriteRegister(CommandReg, PCD_TRANSCEIVE);
     MFRC522_SetBitMask(BitFramingReg, 0x80);
 
     _delay_ms(1);
     uint8_t irq = MFRC522_ReadRegister(CommIrqReg);
     return irq & 0x01 ? false : true;
 }
 
 void MFRC522_Halt(void) {
     MFRC522_WriteRegister(FIFODataReg, PICC_HALT);
     MFRC522_WriteRegister(CommandReg, PCD_TRANSCEIVE);
 }
 