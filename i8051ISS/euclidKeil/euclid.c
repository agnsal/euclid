/*
Copyright 2019 Agnese Salutari.
Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and limitations under the License
 */

/*---------------------------------------------------------------------------*/

#include <reg51.h> // To use within KEIL compiler 
//#include <8051.h> // To use within SDCC compiler

/*---------------------------------------------------------------------------*/

void main() {
    
	int x = 100;
	int y = 60;
	int a, b, q, r;

	// ai = bi * qi + ri, at the ith step.
	a = x;
	b = y;
	q = a / b;
	r = a % b;
	
	while(r != 0){
		// Outputs:
		P0 = a;
		P1 = b;
		P2 = q;
		P3 = r;

		//Next step values
		a = b;
		b = r;
		q = a / b;
		r = a % b;
	}

	//Now ri == 0.
	// Outputs:
	P0 = a;
	P1 = b;
	P2 = q;
	P3 = r;

	// Program completion condictions:
	P0 = 0;
	P1 = 0;
	P2 = 0;
	P3 = 0;
	
	while(1);
}

