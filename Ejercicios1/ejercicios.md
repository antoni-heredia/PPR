#Ejercicios Tema 1
## Ejercicio 6 
### Describir un algoritmo para resolver el problema de calcular si el número de ceros y de unos de una secuencia binaria es par o impar (tanto para el número de unos como para el número de ceros). Ilustrarlo con una secuencia de N=21 bits con P=4 y P=8. Suponer que se desea que el resultado se obtenga en todos los procesadores que intervienen en la computación. Modelar el tiempo de ejecución del algoritmo suponiendo que el número de procesadores es una potencia de 2 en función del tamaño de la secuencia N y los parámetros de comunicación ts (latencia) y tw (ancho de banda) de la arquitectura. 

Para este fin creo que usaría la operación MPI_Broadcast, haciendo que cada procesador envié su información a los demás. Asi todos podrán