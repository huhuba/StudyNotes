package com.mashibing.UserConsumer;

import java.util.Map;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import com.netflix.hystrix.contrib.javanica.annotation.HystrixCommand;

@Service
public class RestService {

	
	@Autowired
	RestTemplate template;
	
	@HystrixCommand(defaultFallback = "back")
	public String alive() {
		//           http://localhost:82/User/alive
		String url ="http://USER-PROVIDER/User/alive";
		   // restTemplate   -> 包装了一下 http请求
			// jdbcTemplate
		   //  不包装   httpClient  URL
		String str = template.getForObject(url, String.class);
		System.out.println("str:" + str);
		return str;
	}
	
	
	
	public String back() {
		
		
		return "呵呵";
	}

}
