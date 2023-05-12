package com.kashf.adcbopservice.util;


import org.apache.commons.lang.StringUtils;

import java.util.Base64;

public class CommonFunctions {

    public String appendLeftRightZerosToLong(Long val, int totalLength, int leftPad){
        String leftPadded = String.format("%0"+leftPad+"d", val);
        String righPadded = StringUtils.rightPad(leftPadded, totalLength, "0");

        return righPadded;
    }

    public String[] decodeToken(String token){
        String[] decodedStr = new String[3];
        String[] chunks = token.split("\\.");
        Base64.Decoder decoder = Base64.getDecoder();

        String header = new String(decoder.decode(chunks[0]));
        String payload = new String(decoder.decode(chunks[1]));

        decodedStr[0] = header;
        decodedStr[1] = payload;

        return decodedStr;
    }
}
