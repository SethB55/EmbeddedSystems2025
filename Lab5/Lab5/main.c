#define F_CPU 16000000UL  // 16 MHz clock speed
#include <avr/io.h>
#include <util/delay.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "i2cmaster.h" // Include I2C library for MAX518 DAC
#include "twimaster.c"

#define DAC_ADDRESS 0b01011000 // DAC address for I2C communication (7-bit address)
#define MYUBRR F_CPU/16/9600-1 // Baud rate for USART

// Function declarations
void USART_Init(unsigned int ubrr);
void USART_Transmit(unsigned char data);
void USART_SendString(const char* str);
char USART_Receive(void);
void ADC_Init(void);
uint16_t ADC_Read(void);
void Format_Voltage(uint16_t adc_value, char* buffer);
void I2C_Set_DAC_Voltage(uint8_t channel, float voltage); // I2C command to set DAC voltage

//----------------------------
// USART Initialization
//----------------------------
void USART_Init(unsigned int ubrr) {
	UBRR0H = (unsigned char)(ubrr >> 8);
	UBRR0L = (unsigned char)ubrr;
	UCSR0B = (1 << RXEN0) | (1 << TXEN0); // Enable RX and TX
	UCSR0C = (1 << UCSZ01) | (1 << UCSZ00); // 8 data bits, 1 stop bit
}

//----------------------------
// Transmit a single character via USART
//----------------------------
void USART_Transmit(unsigned char data) {
	while (!(UCSR0A & (1 << UDRE0))); // Wait for the transmit buffer to be empty
	UDR0 = data; // Load data into the USART Data Register
}

//----------------------------
// Send a null-terminated string via USART
//----------------------------
void USART_SendString(const char* str) {
	while (*str) {
		USART_Transmit(*str++); // Transmit each character in the string
	}
}

//----------------------------
// Receive a single character via USART
//----------------------------
char USART_Receive(void) {
	while (!(UCSR0A & (1 << RXC0))); // Wait until data is received
	return UDR0; // Return received byte from USART Data Register
}

//----------------------------
// Initialize ADC
//----------------------------
void ADC_Init(void) {
	ADMUX = (1 << REFS0); // Use AVcc (5V) as reference voltage
	ADCSRA = (1 << ADEN) | 7; // Enable ADC, prescaler 128 (16MHz/128 = 125kHz)
}

//----------------------------
// Read from ADC (Analog Pin A0)
//----------------------------
uint16_t ADC_Read(void) {
	ADMUX &= 0xF0; // Select ADC channel 0 (A0)
	ADCSRA |= (1 << ADSC); // Start conversion
	while (ADCSRA & (1 << ADSC)); // Wait until the conversion is complete
	return ADC; // Return the ADC result (10-bit)
}

//----------------------------
// Convert ADC value to voltage string (e.g., "2.54")
//----------------------------
void Format_Voltage(uint16_t adc_value, char* buffer) {
	float voltage = (adc_value * 5.0) / 1023.0; // Convert ADC value to voltage
	dtostrf(voltage, 4, 2, buffer); // Convert float to string with 2 decimal places
}

//----------------------------
// Set DAC Voltage using I2C
//----------------------------
void I2C_Set_DAC_Voltage(uint8_t channel, float voltage) {
	uint8_t command_byte = 0x00;
	uint8_t output_byte = 0x00;

	// DAC Channel selection: 0 or 1
	if (channel == 0) {
		command_byte = 0b00000000; // Channel 0
		} else if (channel == 1) {
		command_byte = 0b00000100; // Channel 1
	}

	// Convert voltage to DAC output value (assuming 0V to 5V input, 8-bit resolution)
	uint16_t dac_value = (uint16_t)((voltage / 5.0) * 255.0); // 8-bit resolution (0 to 255)

	// Ensure DAC value is within valid range (0 to 255)
	if (dac_value > 255) dac_value = 255;
	if (dac_value < 0) dac_value = 0;

	output_byte = (uint8_t)(dac_value); // The DAC output byte

	i2c_start_wait(DAC_ADDRESS | I2C_WRITE); // Start I2C communication with DAC
	i2c_write(command_byte); // Send command byte
	i2c_write(output_byte); // Send the output byte to set the DAC voltage
	i2c_stop(); // Stop I2C communication
}

//----------------------------
// Main Program
//----------------------------
int main(void) {
	char input[20];       // Buffer for user input command
	char voltage[10];     // Buffer for voltage string
	char message[40];     // Buffer for output message
	uint8_t i = 0;        // Index for input buffer

	USART_Init(MYUBRR); // Initialize USART for communication
	ADC_Init();         // Initialize ADC
	i2c_init();         // Initialize I2C for communication with DAC

	USART_SendString("Send 'G' to get voltage or 'M,n,dt' to get multiple readings, or 'S,c,v' to set DAC voltage.\r\n");

	while (1) {
		char c = USART_Receive(); // Receive user input

		// Collect characters for command
		if (c != '\n' && c != '\r' && i < sizeof(input) - 1) {
			input[i++] = c;
			input[i] = '\0';
		}
		else if (i > 0) {
			input[i] = '\0'; // Null-terminate input string
			i = 0; // Reset index

			// Handle 'G' command - Get voltage reading
			if (strcmp(input, "G") == 0) {
				uint16_t adc = ADC_Read(); // Read ADC value
				Format_Voltage(adc, voltage); // Format the voltage string
				snprintf(message, sizeof(message), "Voltage: %s V\r\n", voltage); // Format message
				USART_SendString(message); // Send message
			}
			// Handle 'M,n,dt' command - Multiple voltage readings
			else if (input[0] == 'M') {
				int n = 0, dt = 0;
				if (sscanf(input, "M,%d,%d", &n, &dt) == 2 && n >= 2 && n <= 20 && dt >= 1 && dt <= 10) {
					snprintf(message, sizeof(message), "Taking %d readings every %d sec:\r\n", n, dt);
					USART_SendString(message);

					for (int j = 0; j < n; j++) {
						uint16_t adc = ADC_Read(); // Read ADC value
						Format_Voltage(adc, voltage); // Format the voltage string
						snprintf(message, sizeof(message), "%2d: %s V\r\n", j + 1, voltage); // Format message
						USART_SendString(message); // Send message
						_delay_ms(dt * 1000); // Delay between readings
					}
					} else {
					USART_SendString("Invalid format or range! Use M,n,dt (n:2-20, dt:1-10)\r\n");
				}
			}
			// Handle 'S,c,v' command - Set DAC voltage
			else if (input[0] == 'S') {
				uint8_t channel = 0;
				float voltage = 0;
				if (sscanf(input, "S,%hhd,%f", &channel, &voltage) == 2 && (channel == 0 || channel == 1) && voltage >= 0.0 && voltage <= 5.0) {
					// Set DAC voltage
					I2C_Set_DAC_Voltage(channel, voltage);
					snprintf(message, sizeof(message), "DAC channel %d set to %.2f V\r\n", channel, voltage);
					USART_SendString(message); // Send confirmation message
					} else {
					USART_SendString("Invalid 'S' command format or range! Use 'S,c,v' (c:0 or 1, v: 0.0-5.0)\r\n");
				}
			}
			else {
				USART_SendString("Unknown command. Use 'G', 'M,n,dt', or 'S,c,v'\r\n");
			}
		}
	}
}
