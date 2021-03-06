using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class FakeAnimationController : MonoBehaviour
{
    // Start is called before the first frame update
    float timestep = 3.2f;
    void Start()
    {
        
    }

    // Update is called once per frame
    void Update()
    {   
        timestep-=0.0005f;
        if(timestep<=-3.0f){
            timestep = 3.2f;
        }
        gameObject.GetComponent<Renderer>().material.SetFloat("_Paramtest",timestep);
    }
}
