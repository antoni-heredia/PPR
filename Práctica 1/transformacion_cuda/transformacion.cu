#include <stdio.h>
#include <stdlib.h>
#include <iostream>
#include <math.h>
#include <sys/time.h>

// CUDA runtime
//#include <cuda_runtime.h>

// helper functions and utilities to work with CUDA
//#include <helper_functions.h>
//#include <helper_cuda.h>

using namespace std;

__global__ void transformacion(float *A, float *B, float *C,int n){
  int i = threadIdx.x + blockDim.x * blockIdx.x;
  if(i < n){

    int inicio = blockIdx.x * blockDim.x;
    int final = inicio+blockDim.x;
    float suma = 0;
    for(int x = inicio; x < final; x++){
      if(x<n){
        float aux = A[x]*i;
        suma += aux;
        suma += ((int)ceil(aux) % 2 == 0) ? B[x] : -B[x];

      }
    }
    C[i] = suma;
  }
}

__global__ void transformacion_compartida(float *A, float *B, float *C,int n){

  extern __shared__ float sdata[]; 
  float *sA = sdata; 	   
  float *sB = sdata+blockDim.x;    
  
  int i = threadIdx.x + blockDim.x * blockIdx.x;

  if(i < n){
    sA[threadIdx.x] = A[i]; 
    sB[threadIdx.x] = B[i];
    __syncthreads();

    float suma = 0;
    for(int x = 0; x < blockDim.x; x++){
      if(x<n){
        float aux = sA[x]*i;
        suma += aux;
        suma += ((int)ceil(aux) % 2 == 0) ? sB[x] : -sB[x];
      }
    }
    C[i] = suma;
  }
}

__global__ void suma_bloque(float *C,float*D,int n){

  extern __shared__ float sdata[];
  int tid = threadIdx.x;
  int i = blockIdx.x *blockDim.x  + threadIdx.x;
  sdata[tid] = ((i < n) ? C[i] : 0.0f);

  __syncthreads();

  for (int s = blockDim.x / 2; s > 0; s >>= 1)
  {
    if (tid < s)
    {
      sdata[tid] += sdata[tid + s];
    }
    __syncthreads();
  }

  if (tid == 0){
    D[blockIdx.x] = sdata[tid];
  }

}
__global__ void mayor(float * C,float * E, int N){
  extern __shared__ float sdata[];
  int tid = threadIdx.x;
  int i = blockIdx.x *blockDim.x  + threadIdx.x;
  sdata[tid] = ((i < N) ? C[i] : 0.0f);
  __syncthreads();

  for (int s = blockDim.x / 2; s > 0; s >>= 1)
  {
    if (tid < s)
    {
      sdata[tid] = (sdata[tid + s] > sdata[tid]) ? sdata[tid+s] : sdata[tid];
    }
    __syncthreads();
  }

  if (tid == 0){
    E[blockIdx.x] = sdata[tid];
  }

}
//**************************************************************************
int main(int argc, char *argv[])
//**************************************************************************
{
  int Bsize, NBlocks;
  if (argc != 3)
  {
    cout << "Uso: transformacion Num_bloques Tam_bloque  " << endl;
    return (0);
  }
  else
  {
    NBlocks = atoi(argv[1]);
    Bsize = atoi(argv[2]);
  }

  const int N = Bsize * NBlocks;
  //* pointers to host memory */

  float *A, *B, *C, *D, *E;
  float *A_device, *B_device, *C_device, * D_device, *E_device;
  //* Allocate arrays a, b and c on host*/
  A = new float[N];
  B = new float[N];
  C = new float[N];
  D = new float[NBlocks];
  E = new float[NBlocks];

  int size = N*sizeof(float);
  int size_d = NBlocks*sizeof(float);
  cudaError_t err;

  err = cudaMalloc((void **) &A_device, size);
	if (err != cudaSuccess) {
		cout << "ERROR RESERVA" << endl;
  }
  err = cudaMalloc((void **) &B_device, size);
	if (err != cudaSuccess) {
		cout << "ERROR RESERVA" << endl;
  }
  err = cudaMalloc((void **) &C_device, size);
	if (err != cudaSuccess) {
		cout << "ERROR RESERVA" << endl;
  }
  err = cudaMalloc((void **) &D_device,size_d);
	if (err != cudaSuccess) {
		cout << "ERROR RESERVA" << endl;
  }
  err = cudaMalloc((void **) &E_device,size_d);
	if (err != cudaSuccess) {
		cout << "ERROR RESERVA" << endl;
  }
  //float mx; // maximum of C

  //* Initialize arrays A and B */
  for (int i = 0; i < N; i++)
  {
    A[i] = (float)(1 - (i % 100) * 0.001);
    B[i] = (float)(0.5 + (i % 10) * 0.1);
    //A[i] = 0;
    //B[i] = 1;
  }

  // Time measurement
  double t1 = clock();
  //Copio los datos de host a device
  err = cudaMemcpy(A_device, A, size, cudaMemcpyHostToDevice);
	if (err != cudaSuccess) {
		cout << "ERROR COPIA A GPU" << endl;
  }
  err = cudaMemcpy(B_device, B, size, cudaMemcpyHostToDevice);
	if (err != cudaSuccess) {
		cout << "ERROR COPIA A GPU" << endl;
  }

  int blockSize = Bsize;
  int blockNum = NBlocks;

  transformacion<<<blockNum,blockSize, blockSize*2*sizeof(float)>>>(A_device,B_device,C_device, N);
  suma_bloque<<<blockNum,blockSize, blockSize*sizeof(float)>>>(C_device,D_device,N);
  mayor<<<blockNum,blockSize, blockSize*sizeof(float)>>>(C_device,E_device,N);

  err = cudaGetLastError();

  if (err != cudaSuccess) {
      fprintf(stderr, "Failed to launch transformacion shared kernel!\n");
      cout << err << endl;
      exit(EXIT_FAILURE);
  }

  err = cudaMemcpy(D, D_device, size_d, cudaMemcpyDeviceToHost);
	if (err != cudaSuccess) {
		cout << "ERROR COPIA A GPU C" << endl;
  }

  err = cudaMemcpy(E, E_device, size_d, cudaMemcpyDeviceToHost);
	if (err != cudaSuccess) {
		cout << "ERROR COPIA A GPU C" << endl;
  }

  double t2 = clock();
  t2 = (t2 - t1) / CLOCKS_PER_SEC;
  
  for(int c = 0; c < NBlocks ; c++){
    cout << "D[" << c << "]=" << D[c] << endl;
  }

  float mayor = 0;
  for(int c = 0; c < NBlocks ; c++){
    mayor = (mayor > E[c]) ? mayor : E[c];
  }
  cout << "El valor máximo en C es:  " << mayor << endl;
  cout << "N=" << N << "= " << Bsize << "*" << NBlocks << "  ........  Tiempo gastado CPU= " << t2 << endl
  << endl;  /*
  //for (int i=0; i<N;i++)   cout<<"C["<<i<<"]="<<C[i]<<endl;
  cout << "................................." << endl;
  for (int k = 0; k < NBlocks; k++)
    cout << "D[" << k << "]=" << D[k] << endl;
  //cout << "................................." << endl
  //     << "El valor máximo en C es:  " << mx << endl;

  cout << endl
       << "N=" << N << "= " << Bsize << "*" << NBlocks << "  ........  Tiempo gastado CPU= " << t2 << endl
       << endl;
*/
  //* Free the memory */
  delete (A);
  delete (B);
  delete (C);
  delete (D);
  delete (E);

}