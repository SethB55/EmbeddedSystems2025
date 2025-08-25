/*
 * Lab5.c
 *
 * Created: 4/14/2025 3:36:03 PM
 * Author : Adrian Alvarez & Seth Bolen
 * Description: Lab 5 - ADC voltage reading, USART command interface,
 *              and DAC output via I2C.
 */

#define F_CPU 16000000UL  // 16 MHz clock
#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <i2cmaster.h>

//----------------------------
// Initialize Serial (USART0)
//----------------------------
void USART_Init(unsigned int ubrr) {
	UBRR0H = (unsigned char)(ubrr >> 8);
	UBRR0L = (unsigned char)ubrr;
	UCSR0B = (1 << RXEN0) | (1 << TXEN0);
	UCSR0C = (1 << UCSZ01) | (1 << UCSZ00);
}

//----------------------------
// Send one character
//----------------------------
void USART_Transmit(char data) {
	while (!(UCSR0A & (1 << UDRE0)));
	UDR0 = data;
}

//----------------------------
// Send a string
//----------------------------
void USART_SendString(const char* str) {
	while (*str) USART_Transmit(*str++);
}

//----------------------------
// Receive one character
//----------------------------
char USART_Receive(void) {
	while (!(UCSR0A & (1 << RXC0)));
	return UDR0;
}

//----------------------------
// Initialize ADC
//----------------------------
void ADC_Init(void) {
	ADMUX = (1 << REFS0); // AVcc as reference
	ADCSRA = (1 << ADEN) | 7; // Enable ADC, prescaler = 128
}

//----------------------------
// Read ADC value from channel 0
//----------------------------
uint16_t ADC_Read(void) {
	ADMUX &= 0xF0; // Select ADC0
	ADCSRA |= (1 << ADSC); // Start conversion
	while (ADCSRA & (1 << ADSC)); // Wait for conversion to complete
	return ADC;
}

//----------------------------
// Format ADC voltage string
//----------------------------
void Format_Voltage(uint16_t adc_value, char* buffer) {
	float voltage = (adc_value * 5.0) / 1023.0;
	dtostrf(voltage, 4, 2, buffer);
}

//----------------------------
// Set DAC output using I2C
//----------------------------
void DAC_SetOutput(uint8_t channel, float voltage) {
	if (channel > 1 || voltage < 0.0 || voltage > 5.0) return;

	uint8_t dac_value = (uint8_t)((voltage / 5.0) * 255 + 0.5);
	uint8_t command = channel << 4;

	i2c_start(0x50);          // Start I2C with device address
	i2c_write(command);       // Send command byte
	i2c_write(dac_value);     // Send DAC value
	i2c_stop();               // End I2C transmission
}

//----------------------------
// Main Program
//----------------------------
int main(void) {
	char input[20];
	char voltage[10];
	char message[40];
	uint8_t i = 0;

	USART_Init(103);  // 9600 baud at 16 MHz
	ADC_Init();
	i2c_init();

	USART_SendString("Send 'G', 'M,n,dt', or 'S,c,v'\r\n");

	while (1) {
		char c = USART_Receive();

		// Build input string until newline
		if (c != '\n' && c != '\r' && i < sizeof(input) - 1) {
			input[i++] = c;
			input[i] = '\0';
		}
		else if (i > 0) {
			snprintf(message, sizeof(message), "Received: %s\r\n", input);
			USART_SendString(message);
			input[i] = '\0';
			i = 0;

			if (strcmp(input, "G") == 0) {
				uint16_t adc = ADC_Read();
				Format_Voltage(adc, voltage);
				snprintf(message, sizeof(message), "Voltage: %s V\r\n", voltage);
				USART_SendString(message);
			}
			else if (input[0] == 'M') {
				int n = 0, dt = 0;
				if (sscanf(input, "M,%d,%d", &n, &dt) == 2 && n >= 2 && n <= 20 && dt >= 1 && dt <= 10) {
					snprintf(message, sizeof(message), "Taking %d readings every %d sec:\r\n", n, dt);
					USART_SendString(message);
					for (int j = 0; j < n; j++) {
						uint16_t adc = ADC_Read();
						Format_Voltage(adc, voltage);
						snprintf(message, sizeof(message), "t=%d s, v=%s V\r\n", j * dt, voltage);
						USART_SendString(message);
						for (int k = 0; k < dt * 1000; k++) _delay_ms(1);
					}
					} else {
					USART_SendString("Invalid format or range! Use M,n,dt (n:2-20, dt:1-10)\r\n");
				}
			}
			else if (strncmp(input, "S,", 2) == 0) {
				int ch = 0;
				float v = 0.0;
				char* voltage_str = NULL;

				if (sscanf(input + 2, "%d,", &ch) == 1) {
					voltage_str = strchr(input + 2, ',');
					if (voltage_str != NULL) {
						voltage_str++; // Move past comma
						char* endptr;
						v = strtod(voltage_str, &endptr);
						while (*endptr == '\r' || *endptr == '\n') endptr++;
						if (*endptr == '\0' && (ch == 0 || ch == 1) && v >= 0.0 && v <= 5.0) {
							DAC_SetOutput(
							ch, v);
							uint8_t dac_val = (uint8_t)((v / 5.0) * 255 + 0.5);
							char v_str[10];
							dtostrf(v, 4, 2, v_str);
							snprintf(message, sizeof(message), "DAC channel %d set to %s V (%dd)\r\n", ch, v_str, dac_val);
							USART_SendString(message);
							} else {
							USART_SendString("Invalid format or range! Use S,c,v (c:0-1, v:0.00-5.00)\r\n");
						}
						} else {
						USART_SendString("Missing voltage value. Format: S,c,v\r\n");
					}
					} else {
					USART_SendString("Invalid channel. Format: S,c,v\r\n");
				}
			}
			else {
				USART_SendString("Unknown command. Use 'G', 'M,n,dt', or 'S,c,v'\r\n");
			}
		}
	}
}
