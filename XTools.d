module XTools;

/*
* Полезные функции на все случаи жизни
*/

import std.algorithm;
import std.array;
import std.string;
import std.stdio;
import std.conv;
import std.container;
import std.random;
import std.traits;
import std.variant;
import std.typecons;
import std.datetime;
import std.windows.charset;
import std.traits;
import std.range;
import std.functional; 
import core.stdc.string;

/** облегченный вариант to!string(Value). 
ПРИМЕР: int i=7; assert( i.str == "7" );
*/
string str(T)(T v){
	return to!string(v);
}

/** облегченный вариант конверсии числа в строку наподобие format("%9.4f", 34234.54345)
указываются два параметра: 
p1. общее число символов (не менее) в выводимом числе, 
p2 - число знаков поле запятой, не менее (по умолчанию = 2)
для целых чисел имеет смысл только первый параметр
*/
string str(T)(T v, int p1, int p2 = 2 ) if(isNumeric!T){
	static if (is(T == float) || is(T == double) || is(T == real))
		return format("%"~to!string(p1)~"."~to!string(p2)~"f", v);
	else
		return format("%"~to!string(p1)~"d", v); // to!string(v);
		
}

/*
string str2(T, alias p1 )(T v) {
	static if (is(T == float) || is(T == double) || is(T == real))
		//return format("%"~to!string(p1)~"."~to!string(p2)~"f", v);
		return format("%"~to!string(p1)~"f", v);
		//mixin("return format(\"%\""~to!string(p1)~"."~to!string(p2)~"f\", v);");
	else
		return format("%"~to!string(p1)~"d", v); // to!string(v);
		
}
*/

/** конвертирует из string в double, в строках может быть произвольный разделитель дробей
assert( "343.467".toDouble == 343.467 )
assert( "3,1415".toDouble == 3.1415 )
 */
double toDouble(string s){
	return to!double(s.tr(",","."));
}

/*
string ANSI(string s){

	auto ptr = toMBSz(s, 0);
	auto _ptr = ptr;
	int len;
	for(_ptr=ptr; *_ptr != 0; _ptr++, len++) {}
	
	char[] res = new char[len];
	for(int i=0; *ptr != 0; ptr++, i++) {
		res[i]= *ptr;
	}
		
	return to!string(res);
}
*/

/** конвертирует строку из utf в ansi (code page 1251)
writeln( "раз два три".ANSI );
*/
string ANSI(string s){
	return to!string(toMBSz(s, 0));
}

/** конвертирует строку из utf в oem (code page 866)
writeln( "раз два три".OEM );
*/
string OEM(string s){
	return to!string(toMBSz(s, 1));
}

/** более удобный вариант встренного таймера StopWatch */
struct XStopWatch {
	StopWatch sw;
	string name;
	void start(string s=""){ name=s; sw.start; }
	void stop(){ sw.stop; }
	void reset(){ sw.reset; }
	TickDuration peek() { return sw.peek;}
	
	/** возвращает количество миллисекунд */
	long msecs(){ return sw.peek.msecs; }
	
	/** возвращает количество время в секуднах(с дробной частью) в виде строки */
	string str() {return (sw.peek.msecs/cast(double)1000).str(6,3); }
	
	/** печатает время в секундах */
	void writeln() { std.stdio.writeln(name ~ str ~ " sec."); }
	
	/** печатает время в секундах */
	void write() { std.stdio.write(name ~ str ~ " sec."); }
}


/** возвращает округленное время до долей указанных в TYPE, с типом округления DIR
DIR="down" (по умолчанию) (округляется в меньшую сторону, лишнее отбрасывается) 
DIR="up"  (округляется в большую сторону)
*/
SysTime timeRound(string TYPE, string DIR="down")(SysTime time) 
if((TYPE == "seconds" || TYPE == "minutes" || TYPE == "hours" ||  TYPE == "days") && (DIR == "down" || DIR == "up"))
{
	
	static if(DIR == "down"){
	
	static if(TYPE == "seconds"){
		return time - dur!"msecs"(time.fracSec.msecs);
	}else static if(TYPE == "minutes"){
		return time -  dur!"seconds"(time.second)- dur!"msecs"(time.fracSec.msecs);
	}else static if(TYPE == "hours"){
		return time - dur!"minutes"(time.minute) - dur!"seconds"(time.second) - dur!"msecs"(time.fracSec.msecs);
	}else static if(TYPE == "days"){ 
		return time - dur!"hours"(time.hour) - dur!"minutes"(time.minute) - dur!"seconds"(time.second) - dur!"msecs"(time.fracSec.msecs);	
	}
	
	}else{
	// вроде бы, еще можно оптимизировать
	static if(TYPE == "seconds"){
		time += dur!"msecs"(999);
		time -= dur!"msecs"(time.fracSec.msecs);
		return time;
		
	}else static if(TYPE == "minutes"){
		time += dur!"msecs"(999);
		time -= dur!"msecs"(time.fracSec.msecs);			
		time += dur!"seconds"(59);
		time -= dur!"seconds"(time.second);
		return time;			
					
	}else static if(TYPE == "hours"){
		time += dur!"msecs"(999);
		time -= dur!"msecs"(time.fracSec.msecs);
		time += dur!"seconds"(59);
		time -= dur!"seconds"(time.second);
		time += dur!"minutes"(59);
		time -= dur!"minutes"(time.minute);			
		return time;
					
	}else static if(TYPE == "days"){ 
		time += dur!"msecs"(999);
		time -= dur!"msecs"(time.fracSec.msecs);
		time += dur!"seconds"(59);
		time -= dur!"seconds"(time.second);
		time += dur!"minutes"(59);
		time -= dur!"minutes"(time.minute);			
		time += dur!"hours"(23);
		time -= dur!"hours"(time.hour);						
		return time;			
	}	
		
	}			
}	

/** возвращает время, выравненное по указанному значению секунд или минут или часов 

при выравнивании на 5
forward == true : 0 как 5, 3 как 5, 5 как 10, 7 как 10
forward == false : 0 как 0, 3 как 0, 5 как 5, 7 как 5

Эти правила подразумеваются тем, что при выравнивании, например, в 5 минут,
происходит разделение на диапазоны 00:00:00 - 00:04:59, 00:05:00 - 00:09:59.. и.т.д.
(можно было бы при forward == true возвращать не 5 а 4:59, но для удобства сделано 5) 

*/
SysTime getAlignedTimeSlice(string TYPE, int NUM, bool forward=true)(SysTime time)
if(TYPE == "seconds" || TYPE == "minutes" || TYPE == "hours" ||  TYPE == "days")
{			
	int new_d;	
	static if (forward){
	
	static if(TYPE == "seconds"){
		static assert(60 % NUM == 0, "NUM not valid");		
		new_d = ((time.second + NUM) / NUM) * NUM;
		if(new_d>=60) {
			time = timeRound!"minutes"(time);
			time += dur!"minutes"(1);
			return time;
		}else{
			time = timeRound!"minutes"(time);
			time += dur!"seconds"(new_d);
			return time;
		}
	}else static if (TYPE == "minutes"){
		static assert(60 % NUM == 0, "NUM not valid");
		new_d = ((time.minute + NUM) / NUM) * NUM;
		if(new_d>=60) {
			time = timeRound!"hours"(time);
			time += dur!"hours"(1);
			return time;
		}else{
			time = timeRound!"hours"(time);
			time += dur!"minutes"(new_d);
			return time;
		}
	}else static if (TYPE == "hours"){
		static assert(24 % NUM == 0, "NUM not valid");
		new_d = ((time.hour + NUM) / NUM) * NUM;
		if(new_d>=24) {
			time = timeRound!"days"(time);
			time += dur!"days"(1);
			return time;
		}else{
			time = timeRound!"days"(time);
			time += dur!"hours"(new_d);
			return time;
		}						
	}else throw new Exception("TYPE not valid ");
	
	}else{	// forward == false
	
	static if(TYPE == "seconds"){	
		static assert(60 % NUM == 0, "NUM not valid");	
		new_d = ((time.second ) / NUM) * NUM;

		time = timeRound!"minutes"(time);
		time += dur!"seconds"(new_d);
		return time;

	}else static if (TYPE == "minutes"){
		static assert(60 % NUM == 0, "NUM not valid");
		new_d = ((time.minute) / NUM) * NUM;

		time = timeRound!"hours"(time);
		time += dur!"minutes"(new_d);
		return time;
		
	}else static if (TYPE == "hours"){
		static assert(24 % NUM == 0, "NUM not valid");
		new_d = ((time.hour) / NUM) * NUM;

		time = timeRound!"days"(time);
		time += dur!"hours"(new_d);
		return time;		
		
	}else throw new Exception("Unknown char in DIM");	
	
	}
	
	//return SysTime.init;		
}


/** возвращает значение с указанным типом (по умолчанию int, и возможен string) из указателя ptr со смещением offset, 
из содержимого в течении length байтов. если тип signed, то значение трактуется с учетом знака.  */
T getValueFromPtr(T = int)(ubyte * ptr, int offset, int length){

	ubyte * beg = ptr;
		
	static if(is(T == byte)||is(T == short)||is(T == int)||is(T == long)){
		
		int i;
		T res;
		while(length--){
			if(length == 0) // старший байт
				res |=  cast(byte)ptr[offset++] << ( i++ * 8); // с учетом знака в старшем байте
			else
				res |= ptr[offset++] << ( i++ * 8);
			
		}
		
	}else static if(is(T == ubyte)||is(T == ushort)||is(T == uint)||is(T == ulong)){	

		int i;
		T res;
		while(length--){
			res |= ptr[offset++] << ( i++ * 8);				
		}			
		
	}else static if(isArray!char){
		T res = new char[length];
		memcpy(  cast(void *) &res[0], ptr+offset, length);
						
	}else static if(is(T == string)){
		
		string res;
		res.length = length;
		memcpy( cast(void *) &res[0], ptr+offset, length);			
		
	}else static if(is(T == float)){
		throw new Exception("float not implemented yet");
	}else static if(is(T == double)){
		throw new Exception("double not implemented yet");
	}
	
	return res;
}


unittest {
	
	//writeln("\n=== xtools unittest ===");
	
	assert( 12341234.646.str(17,2) == "      12341234.65" );
	//writeln("3,1415".toDouble);
	
	bool b=true;
	assert(b.str == "true");

	// writeln("раз два три".ANSI);
	

}



