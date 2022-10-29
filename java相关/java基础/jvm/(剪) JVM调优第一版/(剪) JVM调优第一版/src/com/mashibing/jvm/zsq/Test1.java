package com.mashibing.jvm.zsq;

import java.io.IOException;
import java.net.URL;
import java.util.Enumeration;

public class Test1 {

    public static void main(String[] args) throws IOException {
       /* System.out.println("boot:" + System.getProperty("sun.boot.class.path"));
        System.out.println("ext:" + System.getProperty("java.ext.dirs"));
        System.out.println("app:" + System.getProperty("java.class.path"));*/

        String name = "java/sql/Array.class";
        Enumeration<URL> urls = Thread.currentThread().getContextClassLoader().getResources(name);
        while (urls.hasMoreElements()) {
            URL url = urls.nextElement();
            System.out.println(url.toString());
        }



    }
}
