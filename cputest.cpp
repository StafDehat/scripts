#include <iostream>
#include <vector>
#include <pthread.h>
#include <sys/time.h>
#include <stdio.h>
#include <stdlib.h>

// Author: Troy Engel, I think?  Maybe Keith Fralick.
// Not Andrew Howard, is the point here.

double CpuFrequency=3601.0; // CPU frequency in MHz

pthread_cond_t cv;
pthread_mutex_t m;
pthread_t thread2;

struct timeval before, after;

typedef unsigned long long ticks;
unsigned long long beforeTicks, afterTicks;

static __inline__ ticks getrdtsc()
{
     unsigned a, d;
//     asm("cpuid"); // We don't need to cause a pipeline stall for this test
     asm volatile("rdtsc" : "=a" (a), "=d" (d));

     return (((ticks)a) | (((ticks)d) << 32));
}

void *beginthread2(void *v)
{
   for (;;)
   {
      // Wait for a signal from thread 1
      pthread_mutex_lock(&m);
      pthread_cond_wait(&cv, &m);

      // Some dequeue op would normally be performed here after a spurious wake
      // up test

      // Get the ending ticks
      afterTicks=getrdtsc();
      pthread_mutex_unlock(&m);

      // Display the time elapsed
      std::cout << "Ticks elapsed: " << afterTicks-beforeTicks << " ("
                << (afterTicks-beforeTicks)/CpuFrequency << " us)\n";
   }

   return NULL;
}

int main(int argc, char *argv[])
{
   int core1=0, core2=0;

   if (argc < 3)
   {
      std::cout << "Usage: " << argv[0] << " producer_corenum consumer_corenum" << std::endl;
      return 1;
   }

   // Get core numbers on which to perform the test
   core1 = atoi(argv[1]);
   core2 = atoi(argv[2]);

   std::cout << "Core 1: " << core1 << std::endl;
   std::cout << "Core 2: " << core2 << std::endl;

   pthread_mutex_init(&m, NULL);
   pthread_cond_init(&cv, NULL);

   cpu_set_t cpuset;

   CPU_ZERO(&cpuset);
   CPU_SET(core1, &cpuset);

   // Set affinity of the first (current) thread to core1
   pthread_t self=pthread_self();
   if (pthread_setaffinity_np(self, sizeof(cpu_set_t), &cpuset)!=0)
   {
      perror("pthread_setaffinity_np");
      return 1;
   }

   CPU_ZERO(&cpuset);
   CPU_SET(core2, &cpuset);

   // Create second thread
   pthread_create(&thread2, NULL, beginthread2, NULL);
   // Set affinity of the second thread to core2
   if (pthread_setaffinity_np(thread2, sizeof(cpu_set_t), &cpuset)!=0)
   {
      perror("pthread_setaffinity_np");
      return 1;
   }

   // Run the test
   for (;;)
   {
      // Sleep for one second
      sleep(1);
      // Get the starting ticks
      beforeTicks=getrdtsc();

      // Signal thread 2
      pthread_mutex_lock(&m);
      // Some enqueue op would normally be performed here
      pthread_cond_signal(&cv);
      pthread_mutex_unlock(&m);
   }
}

