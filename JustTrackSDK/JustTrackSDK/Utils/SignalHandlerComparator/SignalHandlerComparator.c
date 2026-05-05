int justtrack_compareSignalHandlers(void (*defaultHandler)(int), void (*previousHandler)(int)) {
    return defaultHandler == previousHandler;
}
