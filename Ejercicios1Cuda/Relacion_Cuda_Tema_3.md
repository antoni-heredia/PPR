# Ejercicios del Tema 3 sobre Programación en CUDA C
## 1. Para el kernel CUDA de suma de vectores, suponiendo que el vector tiene tamaño 4000, cada hebra calcula un elemento diferente del vector de salida y la longitud del tamaño de bloque de hebras es 512 hebras. Responder a las siguientes cuestiones
```
__global__ void VecAdd(float * A, float* B, float* C, int N) { int i = blockIdx.x * blockDim.x + threadIdx.x;
 if (i<N) C[i] = A[i] + B[i];
 }
```

### a. ¿Cuántas hebras habrá en la Grid asociada al kernel?
4096
### b. ¿Cuántos bloques de hebras se procesarán en total?
8
### c. ¿Cuántas hebras del kernel no harán trabajo útil?
96
### d.  Escribir la parte del código en la que se lanzaría el kernel, si quisiéramos sumar vectores de 3000 enteros y se usaran bloques de 128 hebras. ¿Cuál sería el número de hebras de la grid asociada?
int num_block = ceil(3000.0/128);

VecAdd<<num_block,128>>(A,B,C,D)

El numero de hebras seria 3072.
## 2. Modificar el kernel del ejercicio 1 para que cada hebra CUDA calcule dos elementos adyacentes del vector resultado de la suma en lugar de un único elemento.
```
__global__ void VecAdd(float * A, float* B, float* C, int N) { 
    int i = (blockIdx.x * blockDim.x + threadIdx.x)*2;

    if (i<N)
    {
        C[i] = A[i] + B[i];
        int x = i + 1;
        if (x<N) C[x] = A[x] + B[x];
    }

}

int num_block = ceil(3000.0/(2*128));

VecAdd<<num_block,128>>(A,B,C,D)
```

0   1   2   3
0 1 2 3 4 5 6 7
2*n y 2*n+1
## Supongamos que necesitamos escribir un kernel que opera sobre una imagen de tamaño 400 x 900 pixels. Deseamos asignar una hebra para los caĺculos asociados a cada pixel. También queremos usar bloques de hebras cuadrados y el mayor número posible de hebras por bloque (asumiendo capacidad de cómputo 3.0).
### a. Indicar cómo habría que seleccionar las dimensiones de la grid y de los bloques del kernel para dicho propósito

Con floor(sqrt(1024)) = 32 sabemos el numbero de filas y de columnas para tener un bloque cuadrado teniendo el mayor numero de hebras por bloque. 

El numero de bloques lo calcularemos realizando ceil(400/32)*ceil(900/32) = 377 bloques totales.

### b. Indicar también cuántas hebras ociosas esperarías tener.
377*1024-400*900=26048

## Un programador CUDA dice que si lanza un kernel con solo 32 hebras en cada bloque, no necesitará usar la instrucción __syncthreads() cuando una sincronización de barrera es necesaria a nivel de bloque de hebras. Explicar si crees que esto es una buena idea.

No lo necesitas ya que el warp ( que se ejecuta totalmente en paralelo) es ya de tamaño 32. No obstante, de esta forma solo tendrias 512 hebras en paralelo ( ya que el maximo de bloques es de 16 a la vez) frente a las 1024 que podrias tener con capacidad de computo 3.0. No aprovechando asi el solapamiento durante las comunicaciones. 
## Supongamos que un kernel se lanza con 1000 bloques de hebras, cada uno con 512 hebras.

### a.  Si una variable se declara como local al kernel, ¿Cuántas versiones de dicha variable se crearán a lo largo de la ejecución del kernel? 
1000*512=512000
### b. Si una variable se declara como una variable en memoria compartida, ¿Cuántas versiones de dicha variable se crearán a lo largo de la ejecución del kernel?
Tantas como bloques : 1000.

### 7.  Se dispone del siguiente kernel para calcular la suma de matrices cuadradas N x N de elementos de tipo float, donde cada hebra tiene asignado el cálculo de una celda de la matriz resultado C:
Este ejercicio lo tengo que realizar en casa tomando tiempos de ejecución a modo de experimento. (Se usa sobre sobre suma de matrices, el ejemplo de cuda) Ya esta realiado.

###