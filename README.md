# OpenJ9 Build README

## How to Build OpenJ9 on Linux

1. Download and install *IBM SDK for Java 8* from Java Information Manager: http://w3.hursley.ibm.com/java/jim/ibmsdks/java80/index.html
2. Clone the OpenJ9 repository

  > git clone git@github.ibm.com:runtimes/openjdk-jdk9.git

3. Download the FreeMarker library and unpack it into an arbitrary directory:

  > wget https://sourceforge.net/projects/freemarker/files/freemarker/2.3.8/freemarker-2.3.8.tar.gz/download -O freemarker-2.3.8.tar.gz
  
  > tar -xzf freemarker-2.3.8.tar.gz

4. Get all of the J9 sources:

  > cd openjdk-jdk9
  
  > bash get_source.sh 

5. Run `configure` script:

  > bash configure --with-freemarker-jar=/path/to/freemarker-2.3.8/lib/freemarker.jar
  
  **Note:** If *configure* cannot find the *IBM SDK for Java 8*, you might need to use the *configure* option *--with-boot-jdk*.
  
  **e.g:** 
  
  > bash configure --with-freemarker-jar=/path/to/freemarker-2.3.8/lib/freemarker.jar --with-boot-jdk=/path/to/ibm/sdk8
  
6. Compile and build:
  
  > make images

7. Verify your newly built JDK:
  
  > ./build/*/images/jdk/bin/java -version
