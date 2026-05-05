#import "SignalSimulator.h"
#include <signal.h>
#include <stdlib.h>
#include <unistd.h>

@implementation SignalSimulator

+ (void)trigger_sigbus {
    void (*invalidFunction)(void) = (void (*)(void))-1;
    invalidFunction();
}

+ (void)trigger_sigsegv {
    int *nullPointer = NULL;
    *nullPointer = 1;
}

+ (void)trigger_sigpipe {
    int pipefd[2];
    pipe(pipefd);
    close(pipefd[0]);
    write(pipefd[1], "data", 4);
}

@end
