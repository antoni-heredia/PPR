#include "stdio.h"
#include <sys/time.h>

double cpuSecond()
{
  struct timeval tp;
  gettimeofday(&tp, NULL);
  return ((double)tp.tv_sec + (double)tp.tv_usec * 1e-6);
}

__global__ void calcularPI(double *A, double step, int N )
{
  int i = blockIdx.x * blockDim.x + threadIdx.x; // Compute row index
  if (i < N)
  {
    double x = (i + 1 - 0.5) * step;
    A[i] = 4.0 / (1.0 + x * x);
  }
}
__global__ void reduceSum(double *d_V, int n)
{
  extern __shared__ double sdata[];

  int tid = threadIdx.x;
  int i = blockIdx.x * blockDim.x * 2 + threadIdx.x;
  double suma = (i < n) ? d_V[i] : 0;
  if (i + blockDim.x < n) 
    suma += d_V[i + blockDim.x];
  sdata[tid] = suma;
  __syncthreads();

  for (int s = blockDim.x / 2; s > 0; s >>= 1)
  {
    if (tid < s)
    {
      sdata[tid] = suma += sdata[tid + s];
    }
    __syncthreads();
  }
  if (tid == 0)
    d_V[blockIdx.x] = suma;
}
int main()
{

  // Calculo de pi secuencial
  static long num_steps = 1000000;
  double step;

  double t1 = cpuSecond();
  double x, pi, sum = 0.0;
  step = 1.0 / (double)num_steps;
  for (int i = 1; i <= num_steps; i++)
  {
    x = (i - 0.5) * step;
    sum = sum + 4.0 / (1.0 + x * x);
  }
  pi = step * sum;
  double Tcpu = cpuSecond() - t1;
  printf("El resultado de pi secuencial es: %f\n",pi);
  printf("El tiempo secuencial=%f\n", Tcpu);

  /* pointers to host memory */
  /* Allocate arrays A, B and C on host*/
  double *A = (double *)malloc(num_steps * sizeof(double));

  /* pointers to device memory */
  double *A_d;
  /* Allocate arrays a_d, b_d and c_d on device*/
  cudaMalloc((void **)&A_d, sizeof(double) * num_steps);

  t1 = cpuSecond();

  /* Compute the execution configuration */
  int threadsPerBlock = 1024;
  int numBlocks = ceil(((float)num_steps) / threadsPerBlock);
  calcularPI<<<numBlocks, threadsPerBlock>>>(A_d, step, num_steps);

  /* Copy data from deveice memory to host memory */
  cudaMemcpy(A, A_d, sizeof(double) * num_steps, cudaMemcpyDeviceToHost);
  pi = 0;
  for(int i = 0; i < num_steps;i++)
    pi+=A[i];
  pi = pi*step;
  double Tgpu = cpuSecond() - t1;
  printf("El resultado de pi paralelo es: %f\n",pi);
  printf("Tiempo de CPU=%f\n", Tgpu);
  /* Free the memory */
  free(A);
  cudaFree(A_d);
}
