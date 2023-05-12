package com.kashf.adcbopservice.util;

import javax.crypto.Cipher;
import javax.crypto.spec.SecretKeySpec;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.Base64;

public class AESEncryptionDecryption {
    private SecretKeySpec secretKey;
    private byte[] key;
    private final String ALGORITHM = "AES";
    private final int passLength = 16;

    public void prepareSecreteKey(String myKey) {
        MessageDigest sha = null;
        try {
            key = myKey.getBytes(StandardCharsets.UTF_8);
            sha = MessageDigest.getInstance("SHA-512");
            key = sha.digest(key);
            key = Arrays.copyOf(key, passLength);
            secretKey = new SecretKeySpec(key, ALGORITHM);
        } catch (NoSuchAlgorithmException e) {
            e.printStackTrace();
        }
    }

    public String encrypt(String strToEncrypt, String secret) {
        try {
            prepareSecreteKey(secret);
            Cipher cipher = Cipher.getInstance(ALGORITHM);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey);
            return Base64.getEncoder().encodeToString(cipher.doFinal(strToEncrypt.getBytes("UTF-8")));
        } catch (Exception e) {
            System.out.println("Error while encrypting: " + e.toString());
        }
        return null;
    }

    public String decrypt(String strToDecrypt, String secret) {
        try {
            prepareSecreteKey(secret);
            Cipher cipher = Cipher.getInstance(ALGORITHM);
            cipher.init(Cipher.DECRYPT_MODE, secretKey);
            return new String(cipher.doFinal(Base64.getDecoder().decode(strToDecrypt)));
        } catch (Exception e) {
            System.out.println("Error while decrypting: " + e.toString());
        }
        return null;
    }

    public static void main(String[] args) {
        final String secretKey = "HBL";
        // String originalString = "test@123";
        String originalString = "hbl@22$KF";
        /*final String secretKey = "ME";
        String originalString = "micro@123";*/

        AESEncryptionDecryption aesEncryptionDecryption = new AESEncryptionDecryption();
        String encryptedString = aesEncryptionDecryption.encrypt(originalString, secretKey);
        String decryptedString = aesEncryptionDecryption.decrypt(encryptedString, secretKey);

        System.out.println(originalString);
        System.out.println(encryptedString);
        System.out.println(decryptedString);

        System.out.println(originalString.substring(2));

        // CommonFunctions commonFunctions = new CommonFunctions();
        //System.out.println(commonFunctions.appendLeftRightZerosToLong(5120L, 14, 11));

        //
        /*String padded = String.format("%03d" , 7);*/
        //System.out.println("Integer number left padded with zero : " + padded);

        //
        /*System.out.println("Without Math Ceiling: " + ((60000/100) * 20.385));
        System.out.println("Math Ceiling: " + Math.ceil((60000/100) * 20.385));*/

    }
}
